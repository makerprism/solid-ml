(** Ownership and disposal tracking. *)

type t = Runtime.owner

let create ?parent () : t =
  { Runtime.cleanups = []; children = []; disposed = false; parent; contexts = [] }

let rec dispose (owner : t) =
  if not owner.Runtime.disposed then begin
    owner.Runtime.disposed <- true;
    (* Remove from parent's children list to avoid memory leak *)
    (match owner.Runtime.parent with
     | Some p -> 
       p.Runtime.children <- List.filter (fun c -> c != owner) p.Runtime.children
     | None -> ());
    (* Dispose children first (reverse order of creation) *)
    List.iter dispose (List.rev owner.Runtime.children);
    owner.Runtime.children <- [];
    (* Run cleanups in reverse order *)
    List.iter (fun cleanup -> cleanup ()) (List.rev owner.Runtime.cleanups);
    owner.Runtime.cleanups <- []
  end

let get_owner () =
  let rt = Runtime.get_current () in
  rt.Runtime.current_owner

let on_cleanup cleanup =
  let rt = Runtime.get_current () in
  match rt.Runtime.current_owner with
  | Some owner ->
    if not owner.Runtime.disposed then
      owner.Runtime.cleanups <- cleanup :: owner.Runtime.cleanups
  | None ->
    (* No owner - cleanup will never be called automatically. *)
    ()

let run_with_owner fn =
  let rt = Runtime.get_current () in
  let parent = rt.Runtime.current_owner in
  let owner = create ?parent () in
  (* Add as child of parent *)
  (match parent with
   | Some p -> p.Runtime.children <- owner :: p.Runtime.children
   | None -> ());
  (* Set as current owner *)
  rt.Runtime.current_owner <- Some owner;
  let result =
    try fn ()
    with e ->
      rt.Runtime.current_owner <- parent;
      raise e
  in
  rt.Runtime.current_owner <- parent;
  (result, fun () -> dispose owner)

let create_root fn =
  (* Ensure we have a runtime *)
  match Runtime.get_current_opt () with
  | Some _ ->
    let _, dispose_fn = run_with_owner fn in
    dispose_fn
  | None ->
    (* Create a temporary runtime for this root *)
    Runtime.run (fun () ->
      let _, dispose_fn = run_with_owner fn in
      dispose_fn
    )
