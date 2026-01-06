(** Component context for passing values down the tree.
    
    Context values are stored on Owner nodes, enabling proper
    isolation between concurrent renders and correct shadowing
    in nested component trees.
    
    This is similar to React's Context API or SolidJS's context.
    
    Example:
    {[
      let theme_context = Context.create "light"
      
      let app () =
        Context.provide theme_context "dark" (fun () ->
          (* All components here see "dark" theme *)
          let theme = Context.use theme_context in
          print_endline theme  (* "dark" *)
        )
    ]}
*)

(** A context holds a default value and a unique ID *)
type 'a t = {
  id : int;
  default : 'a;
}

(** Atomic counter for generating unique context IDs across domains *)
let next_id = Atomic.make 0

(** Create a new context with a default value.
    
    The default is used when [use] is called outside of any
    [provide] scope for this context. *)
let create default =
  let id = Atomic.fetch_and_add next_id 1 in
  { id; default }

(** Find a context value by walking up the owner tree *)
let rec find_in_owner ctx (owner : Reactive.owner) =
  match List.assoc_opt ctx.id owner.context with
  | Some v -> Some (Obj.obj v)
  | None ->
    match owner.owner with
    | Some parent -> find_in_owner ctx parent
    | None -> None

(** Use (read) a context value.
    
    Looks up the owner tree for a provided value.
    Returns the default if no value was provided. *)
let use ctx =
  match Reactive.get_runtime_opt () with
  | Some rt ->
    (match rt.owner with
     | Some owner ->
       (match find_in_owner ctx owner with
        | Some v -> v
        | None -> ctx.default)
     | None -> ctx.default)
  | None -> ctx.default

(** Provide a context value for a scope.
    
    All [use] calls within [fn] (and its descendants) will
    see the provided value instead of the default.
    
    Context values can be shadowed by nested [provide] calls. *)
let provide ctx value fn =
  match Reactive.get_runtime_opt () with
  | Some rt ->
    (match rt.owner with
     | Some owner ->
       (* Store value on current owner, run fn, restore *)
       let prev_context = owner.context in
       owner.context <- (ctx.id, Obj.repr value) :: owner.context;
       let result =
         try fn ()
         with e ->
           owner.context <- prev_context;
           raise e
       in
       owner.context <- prev_context;
       result
     | None ->
       (* No owner - create a root to hold the context *)
       Reactive.create_root (fun _dispose ->
         let rt = Reactive.get_runtime () in
         match rt.owner with
         | Some owner ->
           owner.context <- (ctx.id, Obj.repr value) :: owner.context;
           fn ()
         | None -> fn ()
       ))
  | None ->
    (* No runtime - create one with a root *)
    Reactive.run (fun () ->
      Reactive.create_root (fun _dispose ->
        let rt = Reactive.get_runtime () in
        match rt.owner with
        | Some owner ->
          owner.context <- (ctx.id, Obj.repr value) :: owner.context;
          fn ()
        | None -> fn ()
      ))
