(** Async resource with loading/error/ready states.
    
    A Resource represents data that may be loading, failed, or ready.
    This is useful for:
    - Route data loading
    - API calls
    - Any async operation
    
    Usage:
    {[
      type user_error =
        | User_not_found of string
        | Fetch_failed of string

      let user_error_to_string = function
        | User_not_found username -> "User not found: " ^ username
        | Fetch_failed msg -> "Fetch failed: " ^ msg

      (* Create a resource with typed errors.
         Prefer Resource.Async for a consistent result-callback API. *)
      let user_resource = Resource.Async.create_with_error
        ~on_error:(fun exn -> Fetch_failed (Printexc.to_string exn))
        (fun set_result ->
          match Api.fetch_user user_id with
          | Ok user -> set_result (Ok user)
          | Error _ -> set_result (Error (User_not_found user_id))
        )
      in

      (* Legacy form (still supported) *)
      let user_resource = Resource.create_async_with_error
        ~on_error:(fun exn -> Fetch_failed (Printexc.to_string exn))
        (fun ~ok ~error ->
          match Api.fetch_user user_id with
          | Ok user -> ok user
          | Error _ -> error (User_not_found user_id)
        )
      in
      
      (* Use in a component *)
      Resource.render
        ~loading:(fun () -> Html.text "Loading...")
        ~error:(fun err ->
          Html.p ~children:[Html.text (user_error_to_string err)] ())
        ~ready:(fun user -> User_card.make ~user ())
        user_resource
    ]}
*)

open Solid_ml

module Signal = Signal.Unsafe

(** {1 Types} *)

(** The state of a resource *)
type ('a, 'e) state =
  | Loading
  | Ready of 'a
  | Error of 'e
  | Pending [@deprecated "Use Loading"]

type ('a, 'e) actions = {
  mutate : ('a option -> 'a) -> unit;
  refetch : unit -> unit;
  set_ready : 'a -> unit;
  set_error : 'e -> unit;
  set_loading : unit -> unit;
}

(** Generate unique IDs for resources (for Suspense tracking) *)
let next_resource_id = ref 0

(** A resource that tracks async data loading *)
type ('a, 'e) resource = {
  state : ('a, 'e) state Signal.t;
  actions : ('a, 'e) actions;
  id : int;  (** Unique ID for Suspense registration tracking *)
}

type ('a, 'e) t = ('a, 'e) resource

(** {1 Creation} *)

(** Create a resource that immediately starts loading.
    
    The fetcher function is called immediately and the resource
    transitions from Loading -> Ready or Loading -> Error.
    
    Note: This is for synchronous initialization. For true async,
    use [create_async] with a callback-based fetcher.
    
    @param on_error Function that maps exceptions into error values
    @param fetcher Function that returns the data or raises an exception *)
let create_with_error ~on_error fetcher =
  let state, set_state = Signal.create Loading in
  let id = !next_resource_id in
  incr next_resource_id;
  
  let do_fetch () =
    set_state Loading;
    try
      let data = fetcher () in
      set_state (Ready data)
    with exn ->
      set_state (Error (on_error exn))
  in
  
  (* Fetch immediately *)
  do_fetch ();
  
  let actions = {
    mutate = (fun fn ->
      let current_value =
        match Signal.peek state with
        | Ready v -> Some v
        | _ -> None
      in
      let new_value = fn current_value in
      set_state (Ready new_value)
    );
    refetch = (fun () -> do_fetch ());
    set_ready = (fun v -> set_state (Ready v));
    set_error = (fun err -> set_state (Error err));
    set_loading = (fun () -> set_state Loading);
  } in

  { state; actions; id }

(** Create a resource that immediately starts loading.
    
    This version uses [Printexc.to_string] for exceptions. For
    structured error types, use [create_with_error].
    
    @param fetcher Function that returns the data or raises an exception *)
let create fetcher =
  create_with_error ~on_error:Printexc.to_string fetcher

(** Create a resource that loads asynchronously.
    
    The fetcher receives callbacks for success and error. The resource
    transitions from Loading -> Ready or Loading -> Error when the
    callbacks fire.
    
    @param on_error Function that maps exceptions into error values
    @param fetcher Function that triggers async loading
      (signature: ok:('a -> unit) -> error:('e -> unit) -> unit) *)
let create_async_with_error ~on_error fetcher =
  let state, set_state = Signal.create Loading in
  let id = !next_resource_id in
  incr next_resource_id;

  let do_fetch () =
    set_state Loading;
    try
      fetcher
        ~ok:(fun data -> set_state (Ready data))
        ~error:(fun err -> set_state (Error err))
    with exn ->
      set_state (Error (on_error exn))
  in

  do_fetch ();

  let actions = {
    mutate = (fun fn ->
      let current_value =
        match Signal.peek state with
        | Ready v -> Some v
        | _ -> None
      in
      let new_value = fn current_value in
      set_state (Ready new_value)
    );
    refetch = (fun () -> do_fetch ());
    set_ready = (fun v -> set_state (Ready v));
    set_error = (fun err -> set_state (Error err));
    set_loading = (fun () -> set_state Loading);
  } in

  { state; actions; id }

(** Create a resource that loads asynchronously.
    
    This version uses [Printexc.to_string] for exceptions. For
    structured error types, use [create_async_with_error].
    
    @param fetcher Function that triggers async loading
      (signature: ok:('a -> unit) -> error:(string -> unit) -> unit) *)
let create_async fetcher =
  create_async_with_error ~on_error:Printexc.to_string fetcher

(** {1 Async Helpers} *)

module Async = struct
  type ('a, 'e) fetch = (('a, 'e) result -> unit) -> unit

  let create_with_error ~on_error (fetcher : ('a, 'e) fetch) =
    create_async_with_error ~on_error (fun ~ok ~error ->
      fetcher (function
        | Ok data -> ok data
        | Error err -> error err))

  let create (fetcher : ('a, string) fetch) =
    create_async (fun ~ok ~error ->
      fetcher (function
        | Ok data -> ok data
        | Error err -> error err))
end

(** Create a resource with an initial value (already ready).
    
    @param value The initial data *)
let of_value value =
  let state, set_state = Signal.create (Ready value) in
  let id = !next_resource_id in
  incr next_resource_id;
  let actions = {
    mutate = (fun fn ->
      let current_value =
        match Signal.peek state with
        | Ready v -> Some v
        | _ -> None
      in
      let new_value = fn current_value in
      set_state (Ready new_value)
    );
    refetch = (fun () -> ());
    set_ready = (fun v -> set_state (Ready v));
    set_error = (fun err -> set_state (Error err));
    set_loading = (fun () -> set_state Loading);
  } in
  { state; actions; id }

(** Create a resource in loading state.
    
    Use [set] to transition to Ready or Error. *)
let create_loading () =
  let state, set_state = Signal.create Loading in
  let id = !next_resource_id in
  incr next_resource_id;
  let actions = {
    mutate = (fun fn ->
      let current_value =
        match Signal.peek state with
        | Ready v -> Some v
        | _ -> None
      in
      let new_value = fn current_value in
      set_state (Ready new_value)
    );
    refetch = (fun () -> set_state Loading);
    set_ready = (fun v -> set_state (Ready v));
    set_error = (fun err -> set_state (Error err));
    set_loading = (fun () -> set_state Loading);
  } in
  { state; actions; id }

(** Create a resource in error state.
    
    @param error Error value *)
let of_error error =
  let state, set_state = Signal.create (Error error) in
  let id = !next_resource_id in
  incr next_resource_id;
  let actions = {
    mutate = (fun fn ->
      let current_value =
        match Signal.peek state with
        | Ready v -> Some v
        | _ -> None
      in
      let new_value = fn current_value in
      set_state (Ready new_value)
    );
    refetch = (fun () -> set_state Loading);
    set_ready = (fun v -> set_state (Ready v));
    set_error = (fun err -> set_state (Error err));
    set_loading = (fun () -> set_state Loading);
  } in
  { state; actions; id }

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
  | Ready _ | Error _ -> false
  | _ -> true

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

(** Get data if ready, otherwise return [default]. *)
let get_or ~default resource =
  match peek resource with
  | Ready data -> data
  | _ -> default

(** Get the error value if error, None otherwise *)
let get_error resource =
  match peek resource with
  | Error err -> Some err
  | _ -> None

(** {1 Updating} *)

(** Set the resource to ready with data *)
let set resource data =
  resource.actions.set_ready data

(** Set the resource to ready with data (alias) *)
let set_ready resource data =
  set resource data

(** Set the resource to error state *)
let set_error resource error =
  resource.actions.set_error error

(** Set the resource to loading state *)
let set_loading resource =
  resource.actions.set_loading ()

(** Refetch the resource (re-run the fetcher).
    
    Only works for resources created with [create]. *)
let refetch resource =
  resource.actions.refetch ()

(** Mutate the resource value (optimistic update) *)
let mutate resource fn =
  resource.actions.mutate fn

(** {1 Transforming} *)

(** Map over the ready value.
    
    If the resource is Ready, applies the function.
    Otherwise returns Loading or Error unchanged. *)
let map_state f resource =
  match read resource with
  | Ready data -> Ready (f data)
  | Error e -> Error e
  | _ -> Loading

(** Map over the ready value, creating a new resource signal.
    
    The mapped resource updates when the source updates. *)
let map f resource =
  let state, set_state = Signal.create Loading in
  let id = !next_resource_id in
  incr next_resource_id;

  let update () =
    set_state (map_state f resource)
  in

  let actions = {
    mutate = (fun _ -> ());
    refetch = (fun () -> refetch resource);
    set_ready = (fun _ -> ());
    set_error = (fun _ -> ());
    set_loading = (fun () -> ());
  } in

  Effect.Unsafe.create (fun () -> update ());

  {
    state;
    actions;
    id;
  }

(** Map over the ready value, creating a new resource signal.
    
    The mapped resource updates when the source updates. *)
let map_signal f resource =
  map f resource

(** {1 Combinators} *)

(** Combine two resources.
    
    Returns Ready only when both are ready.
    Returns Error if either has an error.
    Returns Loading if either is loading (and neither has error).
    Note: the returned resource is read-only; its actions are no-ops
    except for refetch, which forwards to the sources. *)
let combine r1 r2 =
  let state, set_state = Signal.create Loading in
  let id = !next_resource_id in
  incr next_resource_id;

  let update () =
    match read r1, read r2 with
    | Ready a, Ready b -> set_state (Ready (a, b))
    | Error e, _ -> set_state (Error e)
    | _, Error e -> set_state (Error e)
    | _ -> set_state Loading
  in

  let actions = {
    mutate = (fun _ -> ());
    refetch = (fun () -> refetch r1; refetch r2);
    set_ready = (fun _ -> ());
    set_error = (fun _ -> ());
    set_loading = (fun () -> ());
  } in

  Effect.Unsafe.create (fun () -> update ());

  { state; actions; id }

(** Combine a list of resources.
    
    Returns Ready only when all are ready.
    Returns the first Error encountered.
    Returns Loading if any is loading (and none have errors).
    Note: the returned resource is read-only; its actions are no-ops
    except for refetch, which forwards to the sources. *)
let combine_all resources =
  let state, set_state = Signal.create Loading in
  let id = !next_resource_id in
  incr next_resource_id;

  let update () =
    let rec check acc = function
      | [] -> set_state (Ready (List.rev acc))
      | r :: rest ->
        match read r with
        | Ready data -> check (data :: acc) rest
        | Error e -> set_state (Error e)
        | _ -> set_state Loading
    in
    check [] resources
  in

  let actions = {
    mutate = (fun _ -> ());
    refetch = (fun () -> List.iter refetch resources);
    set_ready = (fun _ -> ());
    set_error = (fun _ -> ());
    set_loading = (fun () -> ());
  } in

  List.iter (fun _ -> Effect.Unsafe.create (fun () -> update ())) resources;

  { state; actions; id }

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
    @param error_to_string Convert error values into messages for exceptions
    @param resource The resource to read
    @raise Failure if resource is in Error state *)
let read_suspense ?(error_to_string=(fun _ -> "Resource error")) ~default resource =
  (* Always read the signal to create a dependency - this ensures the
     containing effect/memo re-runs when the resource state changes *)
  let current_state = Signal.get resource.state in
  
  match current_state with
  | Ready data -> data
  | Error err -> failwith (error_to_string err)
  | _ ->
    (* Try to register with Suspense context *)
    (match Suspense.get_state () with
     | None -> 
       (* No Suspense boundary - just return default *)
       default
     | Some suspense_state ->
       (* Increment counter for this loading resource *)
       Suspense.increment suspense_state resource.id;
       default
    )

(** {1 Rendering Helpers} *)

(** Render based on resource state.
    
    @param loading Function to render loading state
    @param error Function to render error state (receives error value)
    @param ready Function to render ready state (receives data)
    @param resource The resource to render *)
let render ~loading ~error ~ready resource =
  match read resource with
  | Error err -> error err
  | Ready data -> ready data
  | _ -> loading ()
