(** Browser-side reactive core using the shared functor.
    
    Uses global refs for runtime storage (safe in single-threaded JS).
    Errors are logged to console instead of re-raised to prevent
    breaking the entire application.
*)

module Internal = Solid_ml_internal

(** {1 Browser Backend with console.error} *)

external console_error : string -> unit = "error" [@@mel.scope "console"]

module Backend_Browser : Internal.Backend.S = struct
  let current_runtime : Internal.Types.runtime option ref = ref None
  
  let get_runtime () = !current_runtime
  let set_runtime rt = current_runtime := rt
  
  (* Browser logs errors to console instead of crashing *)
  let handle_error exn context =
    console_error ("solid-ml: Error in " ^ context ^ ": " ^ Printexc.to_string exn)
end

(** {1 Instantiate with Browser Backend} *)

module R = Internal.Reactive_functor.Make(Backend_Browser)

(** {1 Types} *)

type computation_state = Internal.Types.computation_state = Clean | Stale | Pending
type 'a signal = 'a Internal.Types.signal
type 'a memo = 'a Internal.Types.memo
type owner = Internal.Types.owner
type computation = Internal.Types.computation

(** {1 Signal API} *)

let create_signal = R.create_typed_signal
let get_signal = R.read_typed_signal
let set_signal = R.write_typed_signal
let peek_signal = R.peek_typed_signal
let update_signal s f = set_signal s (f (peek_signal s))

(** {1 Effect API} *)

let create_effect fn =
  let comp = R.create_computation
    ~fn:(fun _ -> fn (); Obj.repr ())
    ~init:(Obj.repr ())
    ~pure:false
    ~initial_state:Stale
  in
  comp.Internal.Types.user <- true;
  
  let rt = R.get_runtime () in
  if rt.Internal.Types.in_update then
    rt.Internal.Types.effects <- comp :: rt.effects
  else
    R.run_updates (fun () -> R.run_top comp) true

let create_effect_with_cleanup fn =
  let cleanup_ref = ref (fun () -> ()) in
  
  let comp = R.create_computation
    ~fn:(fun _ ->
      !cleanup_ref ();
      let new_cleanup = fn () in
      cleanup_ref := new_cleanup;
      Obj.repr ()
    )
    ~init:(Obj.repr ())
    ~pure:false
    ~initial_state:Stale
  in
  comp.Internal.Types.user <- true;
  
  R.on_cleanup (fun () -> !cleanup_ref ());
  
  let rt = R.get_runtime () in
  if rt.Internal.Types.in_update then
    rt.Internal.Types.effects <- comp :: rt.effects
  else
    R.run_updates (fun () -> R.run_top comp) true

let untrack = R.untrack

(** {1 Memo API} *)

let create_memo = R.create_typed_memo
let get_memo = R.read_typed_memo
let peek_memo = R.peek_typed_memo

(** {1 Owner API} *)

let on_cleanup = R.on_cleanup
let get_owner = R.get_owner

let create_root f =
  (* Ensure we have a runtime *)
  let has_runtime = match R.get_runtime_opt () with
    | Some _ -> true
    | None -> false
  in
  if has_runtime then
    R.create_root (fun dispose -> (f (), dispose))
  else begin
    (* Create a runtime for this root *)
    R.run (fun () ->
      R.create_root (fun dispose -> (f (), dispose))
    )
  end

let run_with_owner = create_root

(** {1 Batch API} *)

let batch fn = R.run_updates fn false

(** {1 Context API} *)

type 'a context = {
  id: int;
  default: 'a;
}

let next_context_id = ref 0

let create_context default =
  let id = !next_context_id in
  incr next_context_id;
  { id; default }

let rec find_context_in_owner ctx (owner : owner) =
  match List.assoc_opt ctx.id owner.Internal.Types.context with
  | Some v -> Some (Obj.obj v)
  | None ->
    match owner.Internal.Types.owner with
    | Some parent -> find_context_in_owner ctx parent
    | None -> None

let use_context ctx =
  match R.get_runtime_opt () with
  | Some rt ->
    (match rt.Internal.Types.owner with
     | Some owner ->
       (match find_context_in_owner ctx owner with
        | Some v -> v
        | None -> ctx.default)
     | None -> ctx.default)
  | None -> ctx.default

let provide_context ctx value fn =
  match R.get_runtime_opt () with
  | Some rt ->
    (match rt.Internal.Types.owner with
     | Some owner ->
       let prev = owner.Internal.Types.context in
       owner.Internal.Types.context <- (ctx.id, Obj.repr value) :: prev;
       let result =
         try fn ()
         with e ->
           owner.Internal.Types.context <- prev;
           raise e
       in
       owner.Internal.Types.context <- prev;
       result
     | None -> fn ())
  | None -> fn ()
