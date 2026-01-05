(** Component context for passing values down the tree.

    Context values are stored on Owner nodes, enabling proper
    isolation between concurrent renders and correct shadowing
    in nested component trees.
*)

type 'a t = {
  id : int;
  default : 'a;
}

(** Atomic counter for generating unique context IDs across domains *)
let next_id = Atomic.make 0

let create default =
  let id = Atomic.fetch_and_add next_id 1 in
  { id; default }

(** Find a context value by walking up the owner tree *)
let rec find_in_owner ctx (owner : Runtime.owner) =
  match List.assoc_opt ctx.id owner.Runtime.contexts with
  | Some v -> Some (Obj.obj v)
  | None ->
    match owner.Runtime.parent with
    | Some parent -> find_in_owner ctx parent
    | None -> None

let use ctx =
  match Runtime.get_current_opt () with
  | Some rt ->
    (match rt.Runtime.current_owner with
     | Some owner ->
       (match find_in_owner ctx owner with
        | Some v -> v
        | None -> ctx.default)
     | None -> ctx.default)
  | None -> ctx.default

let provide ctx value fn =
  let rt = Runtime.get_current () in
  match rt.Runtime.current_owner with
  | Some owner ->
    (* Store value on current owner, run fn, restore *)
    let prev_contexts = owner.Runtime.contexts in
    owner.Runtime.contexts <- (ctx.id, Obj.repr value) :: owner.Runtime.contexts;
    let result =
      try fn ()
      with e ->
        owner.Runtime.contexts <- prev_contexts;
        raise e
    in
    owner.Runtime.contexts <- prev_contexts;
    result
  | None ->
    (* No owner - create one to hold the context *)
    let result_ref = ref None in
    let dispose = Owner.create_root (fun () ->
      let rt = Runtime.get_current () in
      match rt.Runtime.current_owner with
      | Some owner ->
        owner.Runtime.contexts <- (ctx.id, Obj.repr value) :: owner.Runtime.contexts;
        result_ref := Some (fn ())
      | None -> 
        result_ref := Some (fn ())
    ) in
    dispose ();
    match !result_ref with
    | Some r -> r
    | None -> fn ()  (* Shouldn't happen, but fallback *)
