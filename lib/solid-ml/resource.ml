(** Resource with loading/error/ready states.
    
    Matches SolidJS createResource API pattern:
    - States: loading, ready, error
    - mutate for optimistic updates
    - refetch for manual re-fetching
    
    Note: For true async operations, use solid-ml-browser/Resource which has
    full async support with callbacks.
    
    Usage:
      type api_error =
        | Fetch_failed of string

      let api_error_to_string = function
        | Fetch_failed msg -> "Fetch failed: " ^ msg

      let data = Resource.create_with_error
        ~on_error:(fun exn -> Fetch_failed (Printexc.to_string exn))
        (fun () -> fetch_data ())
      in
      let { mutate; refetch } = actions in
      mutate (fun old -> "updated");
      refetch ();
    
    @see https://docs.solidjs.com/reference/basic-reactivity/create-resource
 *)

(** {1 Types} *)

type ('a, 'e) resource_state =
  | Loading
  | Ready of 'a
  | Error of 'e
  | Pending [@deprecated "Use Loading"]

type ('a, 'e) state = ('a, 'e) resource_state

type ('a, 'e) resource = {
  mutable state : ('a, 'e) resource_state Signal.t;
  actions : ('a, 'e) resource_actions;
  id : int;
}
and ('a, 'e) resource_actions = {
  mutate : ('a option -> 'a) -> unit;
  refetch : unit -> unit;
  set_ready : 'a -> unit;
  set_error : 'e -> unit;
  set_loading : unit -> unit;
}

type ('a, 'e) t = ('a, 'e) resource
type ('a, 'e) actions = ('a, 'e) resource_actions

(** {1 Internal State} *)

let next_resource_id = ref 0

(** {1 Creation} *)

(** Create a resource with a synchronous fetcher and custom error mapping. *)
let create_with_error ~on_error (fetcher : unit -> 'a)
  : ('a, 'e) resource =
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
  
  do_fetch ();
  { state; actions; id }

(** Returns [(resource, actions)] in SolidJS style. *)
let create_resource (fetcher : unit -> 'a) : ('a, string) resource * ('a, string) resource_actions =
  let resource = create_with_error ~on_error:Printexc.to_string fetcher in
  (resource, resource.actions)

(** SolidJS-style helper with custom error mapping. *)
let create_resource_with_error ~on_error (fetcher : unit -> 'a)
  : ('a, 'e) resource * ('a, 'e) resource_actions =
  let resource = create_with_error ~on_error fetcher in
  (resource, resource.actions)

(** Create a resource with a synchronous fetcher (string errors). *)
let create (fetcher : unit -> 'a) : ('a, string) resource =
  create_with_error ~on_error:Printexc.to_string fetcher

(** Create a resource with an initial value (already ready). *)
let of_value (value : 'a) : ('a, 'e) resource =
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

(** Create a resource in loading state. *)
let create_loading () : ('a, 'e) resource =
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

(** Create a resource in error state. *)
let of_error (error : 'e) : ('a, 'e) resource =
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

(** Get the current state (tracks dependencies) *)
let read resource =
  Signal.get resource.state

(** Get the current state without tracking *)
let peek resource =
  Signal.peek resource.state

(** Check if loading *)
let loading resource =
  match peek resource with
  | Ready _ | Error _ -> false
  | _ -> true

(** Alias for loading *)
let is_loading = loading

(** Check if ready *)
let ready resource =
  match peek resource with Ready _ -> true | _ -> false

(** Alias for ready *)
let is_ready = ready

(** Check if errored *)
let errored resource =
  match peek resource with Error _ -> true | _ -> false

(** Alias for errored *)
let is_error = errored

(** Get error value if errored *)
let error resource =
  match peek resource with Error err -> Some err | _ -> None

(** Alias for error *)
let get_error = error

(** Get data if ready *)
let data resource =
  match peek resource with Ready v -> Some v | _ -> None

(** Alias for data *)
let get_data = data

(** Get value (raises if not ready).
    
    @param error_to_string Convert error values into messages for exceptions. *)
let get ?(error_to_string=(fun _ -> "Resource error")) resource =
  match peek resource with
  | Ready v -> v
  | Error err -> raise (Invalid_argument ("Resource.get: " ^ error_to_string err))
  | _ -> raise (Invalid_argument "Resource.get: not ready")

(** {1 Actions} *)

(** Mutate the resource value (optimistic update) *)
let mutate resource fn =
  resource.actions.mutate fn

(** Refetch the resource *)
let refetch resource =
  resource.actions.refetch ()

(** Set to ready with data *)
let set_ready resource data =
  resource.actions.set_ready data

(** Set resource to a value directly (convenience) *)
let set resource data =
  resource.actions.set_ready data

(** Set to error *)
let set_error resource err =
  resource.actions.set_error err

(** Set to loading *)
let set_loading resource =
  resource.actions.set_loading ()

(** {1 Transforming} *)

let map_state f resource =
  match read resource with
  | Ready v -> Ready (f v)
  | Error err -> Error err
  | _ -> Loading

(** Map over the ready value, returning a derived resource.
    Note: the returned resource is read-only; its actions are no-ops
    except for refetch, which forwards to the source. *)
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

  Effect.create (fun () -> update ());

  { state; actions; id }

(** Combine two resources.
    Note: the returned resource is read-only; its actions are no-ops
    except for refetch, which forwards to the sources. *)
let combine (r1 : ('a, 'e) resource) (r2 : ('b, 'e) resource)
  : (('a * 'b), 'e) resource =
  let state, set_state = Signal.create Loading in
  let id = !next_resource_id in
  incr next_resource_id;
  
  let update () =
    match read r1, read r2 with
    | Ready a, Ready b -> set_state (Ready (a, b))
    | Error a, _ -> set_state (Error a)
    | _, Error b -> set_state (Error b)
    | _ -> set_state Loading
  in

  let actions = {
    mutate = (fun _ -> ());
    refetch = (fun () ->
      refetch r1;
      refetch r2
    );
    set_ready = (fun _ -> ());
    set_error = (fun _ -> ());
    set_loading = (fun () -> ());
  } in
  
  Effect.create (fun () -> update ());
  Effect.create (fun () -> update ());
  
  { state; actions; id }

(** Combine a list of resources.
    Note: the returned resource is read-only; its actions are no-ops
    except for refetch, which forwards to the sources. *)
let combine_all (resources : ('a, 'e) resource list) : ('a list, 'e) resource =
  let state, set_state = Signal.create Loading in
  let id = !next_resource_id in
  incr next_resource_id;
  
  let update () =
    let rec check acc = function
      | [] -> set_state (Ready (List.rev acc))
      | r :: rest ->
        match read r with
        | Ready v -> check (v :: acc) rest
        | Error err -> set_state (Error err)
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
  
  List.iter (fun _ -> Effect.create (fun () -> update ())) resources;
  
  { state; actions; id }

(** {1 Rendering Helpers} *)

(** Render based on resource state *)
let render ~loading ~error ~ready resource =
  match read resource with
  | Error err -> error err
  | Ready v -> ready v
  | _ -> loading ()

module Unsafe = struct
  let create_with_error ~on_error (fetcher : unit -> 'a) : ('a, 'e) resource =
    let state, set_state = Signal.Unsafe.create Loading in
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
          match Signal.Unsafe.peek state with
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

    do_fetch ();
    { state; actions; id }

  let of_value (value : 'a) : ('a, 'e) resource =
    let state, set_state = Signal.Unsafe.create (Ready value) in
    let id = !next_resource_id in
    incr next_resource_id;
    let actions = {
      mutate = (fun fn ->
        let current_value =
          match Signal.Unsafe.peek state with
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

  let create_loading () : ('a, 'e) resource =
    let state, set_state = Signal.Unsafe.create Loading in
    let id = !next_resource_id in
    incr next_resource_id;
    let actions = {
      mutate = (fun fn ->
        let current_value =
          match Signal.Unsafe.peek state with
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

  let of_error (error : 'e) : ('a, 'e) resource =
    let state, set_state = Signal.Unsafe.create (Error error) in
    let id = !next_resource_id in
    incr next_resource_id;
    let actions = {
      mutate = (fun fn ->
        let current_value =
          match Signal.Unsafe.peek state with
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

  let combine (r1 : ('a, 'e) resource) (r2 : ('b, 'e) resource) : (('a * 'b), 'e) resource =
    let state, set_state = Signal.Unsafe.create Loading in
    let id = !next_resource_id in
    incr next_resource_id;

    let update () =
      match read r1, read r2 with
      | Ready a, Ready b -> set_state (Ready (a, b))
      | Error a, _ -> set_state (Error a)
      | _, Error b -> set_state (Error b)
      | _ -> set_state Loading
    in

    let actions = {
      mutate = (fun _ -> ());
      refetch = (fun () ->
        refetch r1;
        refetch r2
      );
      set_ready = (fun _ -> ());
      set_error = (fun _ -> ());
      set_loading = (fun () -> ());
    } in

    Effect.Unsafe.create (fun () -> update ());
    Effect.Unsafe.create (fun () -> update ());

    { state; actions; id }

  let combine_all (resources : ('a, 'e) resource list) : ('a list, 'e) resource =
    let state, set_state = Signal.Unsafe.create Loading in
    let id = !next_resource_id in
    incr next_resource_id;

    let update () =
      let rec check acc = function
        | [] -> set_state (Ready (List.rev acc))
        | r :: rest ->
          match read r with
          | Ready v -> check (v :: acc) rest
          | Error err -> set_state (Error err)
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

  let read = read
  let peek = peek
  let loading = loading
  let is_loading = is_loading
  let ready = ready
  let is_ready = is_ready
  let errored = errored
  let is_error = is_error
  let error = error
  let get_error = get_error
  let data = data
  let get_data = get_data
  let get = get
  let mutate = mutate
  let refetch = refetch
  let set_ready = set_ready
  let set = set
  let set_error = set_error
  let set_loading = set_loading
  let map_state = map_state
  let map = map
  let render = render
end
