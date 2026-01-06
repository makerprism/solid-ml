(** Async resource with loading/error/ready states for browser.
    
    A Resource represents data that may be loading, failed, or ready.
    This browser version supports true async operations via callbacks.
    
    Usage:
    {[
      (* Create a resource with async fetch *)
      let user_resource = Resource.create_async (fun set_result ->
        Fetch.get "/api/user/123" (fun response ->
          match response with
          | Ok data -> set_result (Ok data)
          | Error e -> set_result (Error e)
        )
      ) in
      
      (* Use in a component *)
      Resource.render
        ~loading:(fun () -> Html.text "Loading...")
        ~error:(fun e -> Html.text ("Error: " ^ e))
        ~ready:(fun user -> User_card.make ~user ())
        user_resource
    ]}
*)

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
  state : 'a state Reactive_core.signal;
  set_state : 'a state -> unit;
  refetch : unit -> unit;
  id : int;  (** Unique ID for Suspense registration tracking *)
}

(** {1 Creation} *)

(** Create a resource that immediately starts loading.
    
    The fetcher is called with a callback to set the result.
    
    @param fetcher Function that takes a (result -> unit) callback *)
let create_async fetcher =
  let state = Reactive_core.create_signal Loading in
  let set_state s = Reactive_core.set_signal state s in
  let id = !next_resource_id in
  incr next_resource_id;
  
  let do_fetch () =
    set_state Loading;
    fetcher (function
      | Ok data -> set_state (Ready data)
      | Error msg -> set_state (Error msg)
    )
  in
  
  (* Fetch immediately *)
  do_fetch ();
  
  { state; set_state; refetch = do_fetch; id }

(** Create a resource with a synchronous fetcher.
    
    @param fetcher Function that returns the data or raises *)
let create fetcher =
  let state = Reactive_core.create_signal Loading in
  let set_state s = Reactive_core.set_signal state s in
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
  
  do_fetch ();
  { state; set_state; refetch = do_fetch; id }

(** Create a resource with an initial value (already ready). *)
let of_value value =
  let state = Reactive_core.create_signal (Ready value) in
  let id = !next_resource_id in
  incr next_resource_id;
  { state; set_state = Reactive_core.set_signal state; refetch = (fun () -> ()); id }

(** Create a resource in loading state. *)
let create_loading () =
  let state = Reactive_core.create_signal Loading in
  let id = !next_resource_id in
  incr next_resource_id;
  { state; set_state = Reactive_core.set_signal state; refetch = (fun () -> ()); id }

(** Create a resource in error state. *)
let of_error message =
  let state = Reactive_core.create_signal (Error message) in
  let id = !next_resource_id in
  incr next_resource_id;
  { state; set_state = Reactive_core.set_signal state; refetch = (fun () -> ()); id }

(** {1 Reading} *)

(** Get the current state (tracks dependencies) *)
let read resource =
  Reactive_core.get_signal resource.state

(** Get the current state without tracking *)
let peek resource =
  Reactive_core.peek_signal resource.state

(** Check if loading *)
let is_loading resource =
  match peek resource with Loading -> true | _ -> false

(** Check if error *)
let is_error resource =
  match peek resource with Error _ -> true | _ -> false

(** Check if ready *)
let is_ready resource =
  match peek resource with Ready _ -> true | _ -> false

(** Get data if ready *)
let get_data resource =
  match peek resource with Ready data -> Some data | _ -> None

(** Get error if error *)
let get_error resource =
  match peek resource with Error msg -> Some msg | _ -> None

(** {1 Updating} *)

(** Set to ready with data *)
let set resource data =
  resource.set_state (Ready data)

(** Set to error *)
let set_error resource message =
  resource.set_state (Error message)

(** Set to loading *)
let set_loading resource =
  resource.set_state Loading

(** Refetch the resource *)
let refetch resource =
  resource.refetch ()

(** {1 Transforming} *)

(** Map over the ready value *)
let map f resource =
  match read resource with
  | Ready data -> Ready (f data)
  | Loading -> Loading
  | Error e -> Error e

(** {1 Combinators} *)

(** Combine two resources *)
let combine r1 r2 =
  match read r1, read r2 with
  | Ready a, Ready b -> Ready (a, b)
  | Error e, _ -> Error e
  | _, Error e -> Error e
  | Loading, _ -> Loading
  | _, Loading -> Loading

(** Combine a list of resources *)
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
    
    @param default Value to return while loading
    @param resource The resource to read
    @raise Failure if resource is in Error state *)
let read_suspense ~default resource =
  (* Always read the signal to create a dependency - this ensures the
     containing effect/memo re-runs when the resource state changes *)
  let current_state = Reactive_core.get_signal resource.state in
  
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

(** Render based on resource state *)
let render ~loading ~error ~ready resource =
  match read resource with
  | Loading -> loading ()
  | Error msg -> error msg
  | Ready data -> ready data

(** Render with default loading and error *)
let render_simple ~ready resource =
  render
    ~loading:(fun () -> Html.text "Loading...")
    ~error:(fun msg -> Html.p ~children:[Html.text ("Error: " ^ msg)] ())
    ~ready
    resource

(** {1 Effect Integration} *)

(** Create an effect that runs when resource becomes ready.
    
    The callback is called each time the resource transitions to Ready. *)
let on_ready resource callback =
  Reactive_core.create_effect (fun () ->
    match read resource with
    | Ready data -> callback data
    | _ -> ()
  )

(** Create an effect that runs when resource errors.
    
    The callback is called each time the resource transitions to Error. *)
let on_error resource callback =
  Reactive_core.create_effect (fun () ->
    match read resource with
    | Error msg -> callback msg
    | _ -> ()
  )
