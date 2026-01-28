(** Async resource with loading/error/ready states for browser.
    
    A Resource represents data that may be loading, failed, or ready.
    This browser version supports true async operations via callbacks.
    
    Usage:
    {[
      type user_error =
        | User_not_found of string
        | Fetch_failed of string

      let user_error_to_string = function
        | User_not_found username -> "User not found: " ^ username
        | Fetch_failed msg -> "Fetch failed: " ^ msg

      (* Create a resource with async fetch and typed errors.
         Prefer Resource.Async for a consistent result-callback API. *)
      let user_resource = Resource.Async.create_with_error
        ~on_error:(fun exn -> Fetch_failed (Dom.exn_to_string exn))
        (fun set_result ->
          Fetch.get "/api/user/123" (fun response ->
            match response with
            | Ok data -> set_result (Ok data)
            | Error _ -> set_result (Error (User_not_found "123"))
          )
        )
      in

      (* Legacy form (still supported) *)
      let user_resource = Resource.create_async_with_error
        ~on_error:(fun exn -> Fetch_failed (Dom.exn_to_string exn))
        (fun set_result ->
          Fetch.get "/api/user/123" (fun response ->
            match response with
            | Ok data -> set_result (Ok data)
            | Error _ -> set_result (Error (User_not_found "123"))
          )
        )
      in
      
      (* Use in a component *)
      Resource.render
        ~loading:(fun () -> Html.text "Loading...")
        ~error:(fun e -> Html.text (user_error_to_string e))
        ~ready:(fun user -> User_card.make ~user ())
        user_resource
    ]}
*)

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
  state : ('a, 'e) state Reactive_core.signal;
  actions : ('a, 'e) actions;
  id : int;  (** Unique ID for Suspense registration tracking *)
}

type ('a, 'e) t = ('a, 'e) resource

let decode_field obj name decode =
  match Js.Dict.get obj name with
  | None -> None
  | Some value -> decode value

let decode_resource_state ~decode ?(decode_error=Js.Json.decodeString) (json : Js.Json.t) : ('a, 'e) state option =
  match Js.Json.decodeObject json with
  | None -> None
  | Some obj ->
    (match decode_field obj "status" Js.Json.decodeString with
     | Some "ready" ->
       (match Js.Dict.get obj "data" with
        | None -> None
        | Some data -> (match decode data with Some v -> Some (Ready v) | None -> None))
     | Some "error" ->
       (match Js.Dict.get obj "error" with
        | Some err_json -> (match decode_error err_json with Some err -> Some (Error err) | None -> None)
        | None -> None)
     | Some "loading" -> Some Loading
     | Some "pending" -> Some Loading
     | _ -> None)

let hydrate_state ~key ~decode ~decode_error : ('a, 'e) state option =
  match State.get ~key with
  | None -> None
  | Some json -> decode_resource_state ~decode ~decode_error json

(** {1 Creation} *)

(** Create a resource with async fetch and optional initial state.

    @param initial Optional initial state (Loading, Ready, or Error)
    @param on_error Function that maps exceptions into error values
    @param fetcher Function that takes a (result -> unit) callback *)
let create_async_with_state ~on_error initial fetcher =
  let state = Reactive_core.create_signal initial in
  let set_state s = Reactive_core.set_signal state s in
  let id = !next_resource_id in
  incr next_resource_id;

   let do_fetch () =
    set_state Loading;
    try
      fetcher (function
        | Ok data -> set_state (Ready data)
        | Error err -> set_state (Error err)
      )
    with exn ->
      set_state (Error (on_error exn))
  in

  let actions = {
    mutate = (fun fn ->
      let current_value =
        match Reactive_core.peek_signal state with
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

  (match initial with
   | Ready _ | Error _ -> ()
   | _ -> do_fetch ());

  { state; actions; id }

(** Create a resource with async fetch and typed errors.

    @param on_error Function that maps exceptions into error values
    @param fetcher Function that takes a (result -> unit) callback *)
let create_async_with_error ~on_error fetcher =
  create_async_with_state ~on_error Loading fetcher

(** Create a resource with async fetch (string errors).

    This is a convenience alias that uses [Dom.exn_to_string] for exceptions.
    For structured error types, use [create_async_with_error].

    @param fetcher Function that takes a (result -> unit) callback *)
let create_async fetcher =
  create_async_with_error ~on_error:Dom.exn_to_string fetcher

(** Create a resource with async fetch and hydration support.

    @param revalidate Whether to refetch on hydration
    @param key Hydration key from server state
    @param decode Decoder for JSON data
    @param decode_error Decoder for JSON error values
    @param fetcher Function that takes a (result -> unit) callback *)
let create_async_with_hydration ?(revalidate = false) ?decode_error ~key ~decode fetcher =
  let decode_error = match decode_error with
    | Some fn -> fn
    | None -> Js.Json.decodeString
  in
  match hydrate_state ~key ~decode ~decode_error with
  | Some state ->
    let resource = create_async_with_state ~on_error:Dom.exn_to_string state fetcher in
    if revalidate then resource.actions.refetch ();
    resource
  | None -> create_async fetcher

(** {1 Async Helpers} *)

module Async = struct
  type ('a, 'e) fetch = (('a, 'e) result -> unit) -> unit

  let create_with_state ~on_error initial (fetcher : ('a, 'e) fetch) =
    create_async_with_state ~on_error initial fetcher

  let create_with_error ~on_error (fetcher : ('a, 'e) fetch) =
    create_async_with_error ~on_error fetcher

  let create (fetcher : ('a, string) fetch) =
    create_async fetcher

  let create_with_hydration ?revalidate ?decode_error ~key ~decode (fetcher : ('a, 'e) fetch) =
    create_async_with_hydration ?revalidate ?decode_error ~key ~decode fetcher
end

(** Create a resource with sync fetch and optional initial state.

    @param initial Optional initial state (Loading, Ready, or Error)
    @param on_error Function that maps exceptions into error values
    @param fetcher Function that returns data or raises *)
let create_with_state ~on_error initial fetcher =
  let state = Reactive_core.create_signal initial in
  let set_state s = Reactive_core.set_signal state s in
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

  let actions = {
    mutate = (fun fn ->
      let current_value =
        match Reactive_core.peek_signal state with
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

   (match initial with
    | Ready _ | Error _ -> ()
    | _ -> do_fetch ());

  { state; actions; id }

(** Create a resource with sync fetch and typed errors.

    @param on_error Function that maps exceptions into error values
    @param fetcher Function that returns data or raises *)
let create_with_error ~on_error fetcher =
  create_with_state ~on_error Loading fetcher

(** Create a resource with sync fetch (string errors).

    This is a convenience alias that uses [Dom.exn_to_string] for exceptions.
    For structured error types, use [create_with_error].

    @param fetcher Function that returns data or raises *)
let create fetcher =
  create_with_error ~on_error:Dom.exn_to_string fetcher

(** Create a resource with sync fetch and hydration support.

    @param revalidate Whether to refetch on hydration
    @param key Hydration key from server state
    @param decode Decoder for JSON data
    @param decode_error Decoder for JSON error values
    @param fetcher Function that returns data or raises *)
let create_with_hydration ?(revalidate = false) ?decode_error ~key ~decode fetcher =
  let decode_error = match decode_error with
    | Some fn -> fn
    | None -> Js.Json.decodeString
  in
  match hydrate_state ~key ~decode ~decode_error with
  | Some state ->
    let resource = create_with_state ~on_error:Dom.exn_to_string state fetcher in
    if revalidate then resource.actions.refetch ();
    resource
  | None -> create fetcher

(** Create a resource with an initial value (already ready). *)
let of_value value =
  let state = Reactive_core.create_signal (Ready value) in
  let id = !next_resource_id in
  incr next_resource_id;
  let set_state = Reactive_core.set_signal state in
  let actions = {
    mutate = (fun fn ->
      let current_value =
        match Reactive_core.peek_signal state with
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

(** Create a resource in loading state. *)
let create_loading () =
  let state = Reactive_core.create_signal Loading in
  let id = !next_resource_id in
  incr next_resource_id;
  let set_state = Reactive_core.set_signal state in
  let actions = {
    mutate = (fun fn ->
      let current_value =
        match Reactive_core.peek_signal state with
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

(** Create a resource in error state. *)
let of_error error =
  let state = Reactive_core.create_signal (Error error) in
  let id = !next_resource_id in
  incr next_resource_id;
  let set_state = Reactive_core.set_signal state in
  let actions = {
    mutate = (fun fn ->
      let current_value =
        match Reactive_core.peek_signal state with
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

(** Get the current state (tracks dependencies) *)
let read resource =
  Reactive_core.get_signal resource.state

(** Get the current state without tracking *)
let peek resource =
  Reactive_core.peek_signal resource.state

(** Check if loading *)
let is_loading resource =
  match peek resource with
  | Ready _ | Error _ -> false
  | _ -> true

(** Alias for is_loading *)
let loading = is_loading

(** Check if error *)
let is_error resource =
  match peek resource with Error _ -> true | _ -> false

(** Alias for is_error *)
let errored = is_error

(** Check if ready *)
let is_ready resource =
  match peek resource with Ready _ -> true | _ -> false

(** Alias for is_ready *)
let ready = is_ready

(** Get data if ready *)
let get_data resource =
  match peek resource with Ready data -> Some data | _ -> None

(** Get data if ready, otherwise return [default]. *)
let get_or ~default resource =
  match peek resource with
  | Ready data -> data
  | _ -> default

(** Get error if error *)
let get_error resource =
  match peek resource with Error err -> Some err | _ -> None

(** {1 Updating} *)

(** Set to ready with data *)
let set_ready resource data =
  resource.actions.set_ready data

(** Set to ready with data (alias) *)
let set resource data =
  set_ready resource data

(** Set to error *)
let set_error resource error =
  resource.actions.set_error error

(** Set to loading *)
let set_loading resource =
  resource.actions.set_loading ()

(** Refetch the resource *)
let refetch resource =
  resource.actions.refetch ()

(** Mutate the resource value (optimistic update) *)
let mutate resource fn =
  resource.actions.mutate fn

(** {1 Transforming} *)

(** Map over the ready value *)
let map_state f resource =
  match read resource with
  | Ready data -> Ready (f data)
  | Error e -> Error e
  | _ -> Loading

(** {1 Combinators} *)

(** Create a derived resource from a computation. *)
let create_derived ~refetch compute =
  let state = Reactive_core.create_signal (compute ()) in
  let set_state = Reactive_core.set_signal state in
  let id = !next_resource_id in
  incr next_resource_id;

  Reactive_core.create_effect (fun () -> set_state (compute ()));

  let actions = {
    mutate = (fun _ -> ());
    refetch;
    set_ready = (fun _ -> ());
    set_error = (fun _ -> ());
    set_loading = (fun () -> ());
  } in

  { state; actions; id }

(** Map over the ready value, returning a derived resource.
    Note: the returned resource is read-only; its actions are no-ops
    except for refetch, which forwards to the source. *)
let map f resource =
  create_derived ~refetch:(fun () -> refetch resource) (fun () -> map_state f resource)

(** Combine two resources, returning a derived resource.
    Note: the returned resource is read-only; its actions are no-ops
    except for refetch, which forwards to the sources. *)
let combine r1 r2 =
  let compute () =
    match read r1, read r2 with
    | Ready a, Ready b -> Ready (a, b)
    | Error e, _ -> Error e
    | _, Error e -> Error e
  | _ -> Loading
  in
  create_derived
    ~refetch:(fun () -> refetch r1; refetch r2)
    compute

(** Combine a list of resources, returning a derived resource.
    Note: the returned resource is read-only; its actions are no-ops
    except for refetch, which forwards to the sources. *)
let combine_all resources =
  let compute () =
    let rec check acc = function
      | [] -> Ready (List.rev acc)
      | r :: rest ->
        match read r with
        | Ready data -> check (data :: acc) rest
        | Error e -> Error e
        | _ -> Loading
    in
    check [] resources
  in
  create_derived
    ~refetch:(fun () -> List.iter refetch resources)
    compute

(** {1 Suspense Integration} *)

(** Read resource value with Suspense integration.
    
    - If Ready: returns the data
    - If Loading: registers with nearest Suspense boundary, returns [default]
    - If Error: raises an exception (to be caught by ErrorBoundary)
    
    @param default Value to return while loading
    @param resource The resource to read
    @raise Failure if resource is in Error state *)
let read_suspense ?(error_to_string=(fun _ -> "Resource error")) ~default resource =
  (* Always read the signal to create a dependency - this ensures the
     containing effect/memo re-runs when the resource state changes *)
  let current_state = Reactive_core.get_signal resource.state in
  
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

(** Render based on resource state *)
let render ~loading ~error ~ready resource =
  match read resource with
  | Ready data -> ready data
  | Error err -> error err
  | _ -> loading ()

(** Render with default loading and error *)
let render_simple ?(error_to_string=(fun _ -> "Resource error")) ~ready resource =
  render
    ~loading:(fun () -> Html.text "Loading...")
    ~error:(fun err -> Html.p ~children:[Html.text ("Error: " ^ error_to_string err)] ())
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
    | Error err -> callback err
    | _ -> ()
  )
