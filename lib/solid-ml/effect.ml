(** Reactive effects that auto-track dependencies. *)

type t = {
  mutable disposed : bool;
  mutable cleanup : unit -> unit;
  mutable unsubscribes : (unit -> unit) list;
}

let create_internal ~with_cleanup fn =
  let effect = { disposed = false; cleanup = (fun () -> ()); unsubscribes = [] } in
  let rt = Runtime.get_current () in
  
  (* Re-run function that will be registered as subscriber *)
  let rec run () =
    if not effect.disposed then begin
      (* Run previous cleanup *)
      effect.cleanup ();
      effect.cleanup <- (fun () -> ());
      (* Unsubscribe from previous dependencies *)
      List.iter (fun unsub -> unsub ()) effect.unsubscribes;
      effect.unsubscribes <- [];
      (* Set up to collect new unsubscribes *)
      let prev_unsubscribes = rt.pending_unsubscribes in
      rt.pending_unsubscribes <- [];
      (* Set tracking context so Signal.get registers us *)
      let prev_tracking = rt.tracking_context in
      rt.tracking_context <- Some run;
      (* Run the effect *)
      let new_cleanup = 
        try fn ()
        with e ->
          rt.tracking_context <- prev_tracking;
          effect.unsubscribes <- rt.pending_unsubscribes;
          rt.pending_unsubscribes <- prev_unsubscribes;
          raise e
      in
      if with_cleanup then
        effect.cleanup <- new_cleanup;
      (* Clear tracking context *)
      rt.tracking_context <- prev_tracking;
      (* Store unsubscribes for next run *)
      effect.unsubscribes <- rt.pending_unsubscribes;
      rt.pending_unsubscribes <- prev_unsubscribes
    end
  in
  (* Register for cleanup with current owner *)
  Owner.on_cleanup (fun () ->
    effect.disposed <- true;
    effect.cleanup ();
    List.iter (fun unsub -> unsub ()) effect.unsubscribes;
    effect.unsubscribes <- []
  );
  (* Run immediately *)
  run ();
  effect

let create fn =
  let _ = create_internal ~with_cleanup:false (fun () -> fn (); (fun () -> ())) in
  ()

let create_with_cleanup fn =
  let _ = create_internal ~with_cleanup:true fn in
  ()

let untrack fn =
  match Runtime.get_current_opt () with
  | Some rt ->
    let prev_context = rt.tracking_context in
    rt.tracking_context <- None;
    let result = fn () in
    rt.tracking_context <- prev_context;
    result
  | None ->
    fn ()
