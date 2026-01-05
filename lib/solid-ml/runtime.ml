(** Execution runtime that holds all reactive state.

    Each render/request should create its own runtime to ensure
    thread safety. All reactive operations happen within a runtime context.
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

(** The current runtime - set via run_with *)
let current_runtime : t option ref = ref None

let create () = {
  current_owner = None;
  tracking_context = None;
  pending_unsubscribes = [];
  batching = false;
  pending_notifications = [];
}

let get_current () =
  match !current_runtime with
  | Some rt -> rt
  | None -> failwith "No reactive runtime active. Use Runtime.run_with or Owner.create_root."

let get_current_opt () = !current_runtime

let run_with runtime fn =
  let prev = !current_runtime in
  current_runtime := Some runtime;
  let result =
    try fn ()
    with e ->
      current_runtime := prev;
      raise e
  in
  current_runtime := prev;
  result

(** Create a new runtime and run function within it *)
let run fn =
  let runtime = create () in
  run_with runtime fn
