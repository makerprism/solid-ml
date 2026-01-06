(** Component context for passing values down the tree.
    
    Context values are stored on Owner nodes, enabling proper
    isolation between concurrent renders and correct shadowing
    in nested component trees.
*)

module Internal = Solid_ml_internal

(** A context holds a default value and a unique ID *)
type 'a t = {
  id : int;
  default : 'a;
}

(** Atomic counter for generating unique context IDs across domains *)
let next_id = Atomic.make 0

(** Create a new context with a default value. *)
let create default =
  let id = Atomic.fetch_and_add next_id 1 in
  { id; default }

(** Find a context value by walking up the owner tree *)
let rec find_in_owner ctx (owner : Reactive.owner) =
  match List.assoc_opt ctx.id owner.Internal.Types.context with
  | Some v -> Some (Obj.obj v)
  | None ->
    match owner.Internal.Types.owner with
    | Some parent -> find_in_owner ctx parent
    | None -> None

(** Use (read) a context value.
    
    Looks up the owner tree for a provided value.
    Returns the default if no value was provided. *)
let use ctx =
  match Reactive.get_runtime_opt () with
  | Some rt ->
    (match rt.Internal.Types.owner with
     | Some owner ->
       (match find_in_owner ctx owner with
        | Some v -> v
        | None -> ctx.default)
     | None -> ctx.default)
  | None -> ctx.default

(** Provide a context value for a scope.
    
    All [use] calls within [fn] (and its descendants) will
    see the provided value instead of the default. *)
let provide ctx value fn =
  match Reactive.get_runtime_opt () with
  | Some rt ->
    (match rt.Internal.Types.owner with
     | Some owner ->
       let prev_context = owner.Internal.Types.context in
       owner.Internal.Types.context <- (ctx.id, Obj.repr value) :: owner.context;
       let result =
         try fn ()
         with e ->
           owner.Internal.Types.context <- prev_context;
           raise e
       in
       owner.Internal.Types.context <- prev_context;
       result
     | None ->
       Reactive.create_root (fun _dispose ->
         let rt = Reactive.get_runtime () in
         match rt.Internal.Types.owner with
         | Some owner ->
           owner.Internal.Types.context <- (ctx.id, Obj.repr value) :: owner.context;
           fn ()
         | None -> fn ()
       ))
  | None ->
    Reactive.run (fun () ->
      Reactive.create_root (fun _dispose ->
        let rt = Reactive.get_runtime () in
        match rt.Internal.Types.owner with
        | Some owner ->
          owner.Internal.Types.context <- (ctx.id, Obj.repr value) :: owner.context;
          fn ()
        | None -> fn ()
      ))
