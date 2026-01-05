(** Execution runtime that holds all reactive state.

    Each render/request should create its own runtime to ensure
    thread safety. All reactive operations happen within a runtime context.
    
    Uses Domain-local storage (OCaml 5) for safe parallel execution
    across domains.
*)

type owner = {
  mutable cleanups : (unit -> unit) list;
  mutable children : owner list;
  mutable disposed : bool;
  parent : owner option;
  mutable contexts : (int * Obj.t) list;  (* Context values stored on owner *)
}

type t = {
  mutable current_owner : owner option;
  mutable tracking_context : (unit -> unit) option;
  mutable pending_unsubscribes : (unit -> unit) list;
  mutable batching : bool;
  mutable pending_notifications : (unit -> unit) list;
}

(** Domain-local storage key for current runtime.
    Each domain has its own independent runtime stack. *)
let current_runtime_key : t option Domain.DLS.key = 
  Domain.DLS.new_key (fun () -> None)

let get_current_runtime_opt () =
  Domain.DLS.get current_runtime_key

let set_current_runtime rt =
  Domain.DLS.set current_runtime_key rt

let create () = {
  current_owner = None;
  tracking_context = None;
  pending_unsubscribes = [];
  batching = false;
  pending_notifications = [];
}

let get_current () =
  match get_current_runtime_opt () with
  | Some rt -> rt
  | None -> failwith "No reactive runtime active. Use Runtime.run or Owner.create_root."

let get_current_opt () = get_current_runtime_opt ()

let run_with runtime fn =
  let prev = get_current_runtime_opt () in
  set_current_runtime (Some runtime);
  let result =
    try fn ()
    with e ->
      set_current_runtime prev;
      raise e
  in
  set_current_runtime prev;
  result

(** Create a new runtime and run function within it *)
let run fn =
  let runtime = create () in
  run_with runtime fn
