(** Resource with loading/error/ready states.
    
    Matches SolidJS createResource API pattern:
    - States: pending, ready, errored
    - mutate for optimistic updates
    - refetch for manual re-fetching
    
    Note: For true async operations, use solid-ml-browser/Resource which has
    full async support with callbacks.
    
    Usage:
      let data = Resource.create (fun () -> fetch_data ()) in
      let { mutate; refetch } = actions in
      mutate (fun old -> "updated");
      refetch ();
    
    @see https://docs.solidjs.com/reference/basic-reactivity/create-resource
 *)

(** {1 Types} *)

type 'a resource_state =
  | Pending
  | Ready of 'a
  | Error of string

type 'a resource = {
  mutable state : 'a resource_state Signal.t;
  actions : 'a resource_actions;
  id : int;
}
and 'a resource_actions = {
  mutate : ('a option -> 'a) -> unit;
  refetch : unit -> unit;
  set_ready : 'a -> unit;
  set_error : string -> unit;
}

(** {1 Internal State} *)

let next_resource_id = ref 0

(** {1 Creation} *)

(** Create a resource with a synchronous fetcher. *)
type token = Runtime.token

let create (token : token) (fetcher : unit -> 'a) : 'a resource =
  let state, set_state = Signal.create token Pending in
  let id = !next_resource_id in
  incr next_resource_id;
  
  let do_fetch () =
    set_state Pending;
    try
      let data = fetcher () in
      set_state (Ready data)
    with exn ->
      set_state (Error (Printexc.to_string exn))
  in
  
  let actions = {
    mutate = (fun fn ->
      let new_value = fn None in
      set_state (Ready new_value)
    );
    refetch = (fun () -> do_fetch ());
    set_ready = (fun v -> set_state (Ready v));
    set_error = (fun msg -> set_state (Error msg));
  } in
  
  do_fetch ();
  { state; actions; id }

(** Create a resource with an initial value (already ready). *)
let of_value (token : token) (value : 'a) : 'a resource =
  let state, set_state = Signal.create token (Ready value) in
  let id = !next_resource_id in
  incr next_resource_id;
  let actions = {
    mutate = (fun fn ->
      let new_value = fn (Some value) in
      set_state (Ready new_value)
    );
    refetch = (fun () -> ());
    set_ready = (fun v -> set_state (Ready v));
    set_error = (fun msg -> set_state (Error msg));
  } in
  { state; actions; id }

(** Create a resource in loading state. *)
let create_loading (token : token) : 'a resource =
  let state, set_state = Signal.create token Pending in
  let id = !next_resource_id in
  incr next_resource_id;
  let actions = {
    mutate = (fun fn ->
      let new_value = fn None in
      set_state (Ready new_value)
    );
    refetch = (fun () -> set_state Pending);
    set_ready = (fun v -> set_state (Ready v));
    set_error = (fun msg -> set_state (Error msg));
  } in
  { state; actions; id }

(** Create a resource in error state. *)
let of_error (token : token) (message : string) : 'a resource =
  let state, set_state = Signal.create token (Error message) in
  let id = !next_resource_id in
  incr next_resource_id;
  let actions = {
    mutate = (fun fn ->
      let new_value = fn None in
      set_state (Ready new_value)
    );
    refetch = (fun () -> set_state Pending);
    set_ready = (fun v -> set_state (Ready v));
    set_error = (fun msg -> set_state (Error msg));
  } in
  { state; actions; id }

(** {1 Reading} *)

(** Get the current state (tracks dependencies) *)
let read resource =
  Signal.get resource.state

(** Get the current state without tracking *)
let peek resource =
  Signal.peek resource.state

(** Check if loading (pending) *)
let loading resource =
  match peek resource with Pending -> true | _ -> false

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

(** Get error message if errored *)
let error resource =
  match peek resource with Error msg -> Some msg | _ -> None

(** Alias for error *)
let get_error = error

(** Get data if ready *)
let data resource =
  match peek resource with Ready v -> Some v | _ -> None

(** Alias for data *)
let get_data = data

(** Get value (raises if not ready) *)
let get resource =
  match peek resource with
  | Ready v -> v
  | Pending -> raise (Invalid_argument "Resource.get: not ready")
  | Error msg -> raise (Invalid_argument ("Resource.get: " ^ msg))

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
let set_error resource msg =
  resource.actions.set_error msg

(** {1 Transforming} *)

(** Map over the ready value *)
let map f resource =
  match read resource with
  | Ready v -> Ready (f v)
  | Pending -> Pending
  | Error msg -> Error msg

(** Combine two resources *)
let combine (token : token) (r1 : 'a resource) (r2 : 'b resource) : ('a * 'b) resource =
  let state, set_state = Signal.create token Pending in
  let id = !next_resource_id in
  incr next_resource_id;
  
  let update () =
    match read r1, read r2 with
    | Ready a, Ready b -> set_state (Ready (a, b))
    | Error a, _ -> set_state (Error a)
    | _, Error b -> set_state (Error b)
    | Pending, _ | _, Pending -> set_state Pending
  in
  
  let actions = {
    mutate = (fun fn ->
      let new_value = fn None in
      set_state (Ready new_value)
    );
    refetch = (fun () ->
      refetch r1;
      refetch r2
    );
    set_ready = (fun _ -> ());
    set_error = (fun msg -> set_state (Error msg));
  } in
  
  Effect.create token (fun () -> update ());
  Effect.create token (fun () -> update ());
  
  { state; actions; id }

(** Combine a list of resources *)
let combine_all (token : token) (resources : 'a resource list) : 'a list resource =
  let state, set_state = Signal.create token Pending in
  let id = !next_resource_id in
  incr next_resource_id;
  
  let update () =
    let rec check acc = function
      | [] -> set_state (Ready (List.rev acc))
      | r :: rest ->
        match read r with
        | Ready v -> check (v :: acc) rest
        | Error msg -> set_state (Error msg)
        | Pending -> set_state Pending
    in
    check [] resources
  in
  
  let actions = {
    mutate = (fun fn ->
      let new_value = fn None in
      set_state (Ready new_value)
    );
    refetch = (fun () -> List.iter refetch resources);
    set_ready = (fun _ -> ());
    set_error = (fun msg -> set_state (Error msg));
  } in
  
  List.iter (fun _ -> Effect.create token (fun () -> update ())) resources;
  
  { state; actions; id }

(** {1 Rendering Helpers} *)

(** Render based on resource state *)
let render ~loading ~error ~ready resource =
  match read resource with
  | Pending -> loading ()
  | Error msg -> error msg
  | Ready v -> ready v

module Unsafe = struct
  let create (fetcher : unit -> 'a) : 'a resource =
    let state, set_state = Signal.Unsafe.create Pending in
    let id = !next_resource_id in
    incr next_resource_id;

    let do_fetch () =
      set_state Pending;
      try
        let data = fetcher () in
        set_state (Ready data)
      with exn ->
        set_state (Error (Printexc.to_string exn))
    in

    let actions = {
      mutate = (fun fn ->
        let new_value = fn None in
        set_state (Ready new_value)
      );
      refetch = (fun () -> do_fetch ());
      set_ready = (fun v -> set_state (Ready v));
      set_error = (fun msg -> set_state (Error msg));
    } in

    do_fetch ();
    { state; actions; id }

  let of_value (value : 'a) : 'a resource =
    let state, set_state = Signal.Unsafe.create (Ready value) in
    let id = !next_resource_id in
    incr next_resource_id;
    let actions = {
      mutate = (fun fn ->
        let new_value = fn (Some value) in
        set_state (Ready new_value)
      );
      refetch = (fun () -> ());
      set_ready = (fun v -> set_state (Ready v));
      set_error = (fun msg -> set_state (Error msg));
    } in
    { state; actions; id }

  let create_loading () : 'a resource =
    let state, set_state = Signal.Unsafe.create Pending in
    let id = !next_resource_id in
    incr next_resource_id;
    let actions = {
      mutate = (fun fn ->
        let new_value = fn None in
        set_state (Ready new_value)
      );
      refetch = (fun () -> set_state Pending);
      set_ready = (fun v -> set_state (Ready v));
      set_error = (fun msg -> set_state (Error msg));
    } in
    { state; actions; id }

  let of_error (message : string) : 'a resource =
    let state, set_state = Signal.Unsafe.create (Error message) in
    let id = !next_resource_id in
    incr next_resource_id;
    let actions = {
      mutate = (fun fn ->
        let new_value = fn None in
        set_state (Ready new_value)
      );
      refetch = (fun () -> set_state Pending);
      set_ready = (fun v -> set_state (Ready v));
      set_error = (fun msg -> set_state (Error msg));
    } in
    { state; actions; id }

  let combine (r1 : 'a resource) (r2 : 'b resource) : ('a * 'b) resource =
    let state, set_state = Signal.Unsafe.create Pending in
    let id = !next_resource_id in
    incr next_resource_id;

    let update () =
      match read r1, read r2 with
      | Ready a, Ready b -> set_state (Ready (a, b))
      | Error a, _ -> set_state (Error a)
      | _, Error b -> set_state (Error b)
      | Pending, _ | _, Pending -> set_state Pending
    in

    let actions = {
      mutate = (fun fn ->
        let new_value = fn None in
        set_state (Ready new_value)
      );
      refetch = (fun () ->
        refetch r1;
        refetch r2
      );
      set_ready = (fun _ -> ());
      set_error = (fun msg -> set_state (Error msg));
    } in

    Effect.Unsafe.create (fun () -> update ());
    Effect.Unsafe.create (fun () -> update ());

    { state; actions; id }

  let combine_all (resources : 'a resource list) : 'a list resource =
    let state, set_state = Signal.Unsafe.create Pending in
    let id = !next_resource_id in
    incr next_resource_id;

    let update () =
      let rec check acc = function
        | [] -> set_state (Ready (List.rev acc))
        | r :: rest ->
          match read r with
          | Ready v -> check (v :: acc) rest
          | Error msg -> set_state (Error msg)
          | Pending -> set_state Pending
      in
      check [] resources
    in

    let actions = {
      mutate = (fun fn ->
        let new_value = fn None in
        set_state (Ready new_value)
      );
      refetch = (fun () -> List.iter refetch resources);
      set_ready = (fun _ -> ());
      set_error = (fun msg -> set_state (Error msg));
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
  let map = map
  let render = render
end
