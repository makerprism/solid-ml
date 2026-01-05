(** Reactive effects that auto-track dependencies. *)

let create fn =
  (* Create a re-run function that will be registered as subscriber *)
  let rec run () =
    (* Set tracking context so Signal.get registers us *)
    Signal.set_tracking_context (Some run);
    (* Run the effect *)
    fn ();
    (* Clear tracking context *)
    Signal.set_tracking_context None
  in
  (* Run immediately *)
  run ()

let create_with_cleanup fn =
  let cleanup_ref = ref (fun () -> ()) in
  let rec run () =
    (* Run previous cleanup *)
    !cleanup_ref ();
    (* Set tracking context *)
    Signal.set_tracking_context (Some run);
    (* Run effect and store cleanup *)
    cleanup_ref := fn ();
    (* Clear tracking context *)
    Signal.set_tracking_context None
  in
  run ()

let untrack fn =
  let prev_context = Signal.get_tracking_context () in
  Signal.set_tracking_context None;
  let result = fn () in
  Signal.set_tracking_context prev_context;
  result
