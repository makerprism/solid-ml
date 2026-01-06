(** Async resource with loading/error/ready states.
    
    A Resource represents data that may be loading, failed, or ready.
    This is useful for:
    - Route data loading
    - API calls
    - Any async operation
    
    Usage:
    {[
      (* Create a resource *)
      let user_resource = Resource.create (fun () ->
        Api.fetch_user user_id
      ) in
      
      (* Use in a component *)
      match Resource.read user_resource with
      | Loading -> Html.text "Loading..."
      | Error e -> Html.p ~children:[Html.text ("Error: " ^ e)] ()
      | Ready user -> User_card.make ~user ()
    ]}
*)

open Solid_ml

(** {1 Types} *)

(** The state of a resource *)
type 'a state =
  | Loading
  | Error of string
  | Ready of 'a

(** Generate unique IDs for resources (for Suspense tracking) *)
let next_resource_id = ref 0

(** A resource that tracks async data loading *)
type 'a t = {
  state : 'a state Signal.t;
  set_state : 'a state -> unit;
  refetch : unit -> unit;
  id : int;  (** Unique ID for Suspense registration tracking *)
}

(** {1 Creation} *)

(** Create a resource that immediately starts loading.
    
    The fetcher function is called immediately and the resource
    transitions from Loading -> Ready or Loading -> Error.
    
    Note: This is for synchronous initialization. For true async,
    use [create_async] with a promise-returning function.
    
    @param fetcher Function that returns the data or raises an exception *)
let create fetcher =
  let state, set_state = Signal.create Loading in
  let id = !next_resource_id in
  incr next_resource_id;
  
  let do_fetch () =
    set_state Loading;
    try
      let data = fetcher () in
      set_state (Ready data)
    with exn ->
      set_state (Error (Printexc.to_string exn))
  in
  
  (* Fetch immediately *)
  do_fetch ();
  
  { state; set_state; refetch = do_fetch; id }

(** Create a resource with an initial value (already ready).
    
    @param value The initial data *)
let of_value value =
  let state, set_state = Signal.create (Ready value) in
  let id = !next_resource_id in
  incr next_resource_id;
  { state; set_state; refetch = (fun () -> ()); id }

(** Create a resource in loading state.
    
    Use [set] to transition to Ready or Error. *)
let create_loading () =
  let state, set_state = Signal.create Loading in
  let id = !next_resource_id in
  incr next_resource_id;
  { state; set_state; refetch = (fun () -> ()); id }

(** Create a resource in error state.
    
    @param message Error message *)
let of_error message =
  let state, set_state = Signal.create (Error message) in
  let id = !next_resource_id in
  incr next_resource_id;
  { state; set_state; refetch = (fun () -> ()); id }

(** {1 Reading} *)

(** Get the current state of the resource.
    
    This reads the signal, so it will track dependencies
    when called inside an effect or memo. *)
let read resource =
  Signal.get resource.state

(** Get the current state without tracking.
    
    Use this when you don't want to create a dependency. *)
let peek resource =
  Signal.peek resource.state

(** Check if the resource is loading *)
let is_loading resource =
  match peek resource with
  | Loading -> true
  | _ -> false

(** Check if the resource has an error *)
let is_error resource =
  match peek resource with
  | Error _ -> true
  | _ -> false

(** Check if the resource is ready *)
let is_ready resource =
  match peek resource with
  | Ready _ -> true
  | _ -> false

(** Get the data if ready, None otherwise *)
let get_data resource =
  match peek resource with
  | Ready data -> Some data
  | _ -> None

(** Get the error message if error, None otherwise *)
let get_error resource =
  match peek resource with
  | Error msg -> Some msg
  | _ -> None

(** {1 Updating} *)

(** Set the resource to ready with data *)
let set resource data =
  resource.set_state (Ready data)

(** Set the resource to error state *)
let set_error resource message =
  resource.set_state (Error message)

(** Set the resource to loading state *)
let set_loading resource =
  resource.set_state Loading

(** Refetch the resource (re-run the fetcher).
    
    Only works for resources created with [create]. *)
let refetch resource =
  resource.refetch ()

(** {1 Transforming} *)

(** Map over the ready value.
    
    If the resource is Ready, applies the function.
    Otherwise returns Loading or Error unchanged. *)
let map f resource =
  match read resource with
  | Ready data -> Ready (f data)
  | Loading -> Loading
  | Error e -> Error e

(** Map over the ready value, creating a new resource signal.
    
    The mapped resource updates when the source updates. *)
let map_signal f resource =
  let mapped_state = Memo.create (fun () ->
    match Signal.get resource.state with
    | Ready data -> Ready (f data)
    | Loading -> Loading
    | Error e -> Error e
  ) in
  let id = !next_resource_id in
  incr next_resource_id;
  { 
    state = Obj.magic mapped_state;  (* Memo is read-only signal *)
    set_state = (fun _ -> ());  (* Can't set a mapped resource *)
    refetch = resource.refetch;
    id;
  }

(** {1 Combinators} *)

(** Combine two resources.
    
    Returns Ready only when both are ready.
    Returns Error if either has an error.
    Returns Loading if either is loading (and neither has error). *)
let combine r1 r2 =
  match read r1, read r2 with
  | Ready a, Ready b -> Ready (a, b)
  | Error e, _ -> Error e
  | _, Error e -> Error e
  | Loading, _ -> Loading
  | _, Loading -> Loading

(** Combine a list of resources.
    
    Returns Ready only when all are ready.
    Returns the first Error encountered.
    Returns Loading if any is loading (and none have errors). *)
let combine_all resources =
  let rec check acc = function
    | [] -> Ready (List.rev acc)
    | r :: rest ->
      match read r with
      | Ready data -> check (data :: acc) rest
      | Error e -> Error e
      | Loading -> Loading
  in
  check [] resources

(** {1 Suspense Integration} *)

(** Read resource value with Suspense integration.
    
    - If Ready: returns the data
    - If Loading: registers with nearest Suspense boundary, returns [default]
    - If Error: raises an exception (to be caught by ErrorBoundary)
    
    Use this inside a Suspense boundary:
    
    {[
      Suspense.boundary ~fallback:spinner (fun () ->
        let user = Resource.read_suspense ~default:User.empty user_resource in
        render_user user
      )
    ]}
    
    @param default Value to return while loading (content won't be shown anyway)
    @param resource The resource to read
    @raise Failure if resource is in Error state *)
let read_suspense ~default resource =
  (* Always read the signal to create a dependency - this ensures the
     containing effect/memo re-runs when the resource state changes *)
  let current_state = Signal.get resource.state in
  
  match current_state with
  | Ready data -> data
  | Error msg -> failwith msg
  | Loading ->
    (* Try to register with Suspense context *)
    (match Suspense.get_state () with
     | None -> 
       (* No Suspense boundary - just return default *)
       default
     | Some suspense_state ->
       (* Increment counter for this loading resource *)
       Suspense.increment suspense_state;
       default
    )

(** {1 Rendering Helpers} *)

(** Render based on resource state.
    
    @param loading Function to render loading state
    @param error Function to render error state (receives message)
    @param ready Function to render ready state (receives data)
    @param resource The resource to render *)
let render ~loading ~error ~ready resource =
  match read resource with
  | Loading -> loading ()
  | Error msg -> error msg
  | Ready data -> ready data

(** Render with default loading and error states.
    
    Shows "Loading..." for loading state.
    Shows "Error: {message}" for error state.
    
    @param ready Function to render ready state
    @param resource The resource to render *)
let render_simple ~ready resource =
  render
    ~loading:(fun () -> Solid_ml_html.Html.text "Loading...")
    ~error:(fun msg -> Solid_ml_html.Html.p ~children:[
      Solid_ml_html.Html.text ("Error: " ^ msg)
    ] ())
    ~ready
    resource
