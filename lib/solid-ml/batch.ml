(** Batch multiple signal updates. *)

let is_batching () =
  match Runtime.get_current_opt () with
  | Some rt -> rt.batching
  | None -> false

let queue_notification notify =
  match Runtime.get_current_opt () with
  | Some rt when rt.batching ->
    (* Deduplicate notifications *)
    if not (List.memq notify rt.pending_notifications) then
      rt.pending_notifications <- notify :: rt.pending_notifications
  | _ ->
    notify ()

let run fn =
  let rt = Runtime.get_current () in
  if rt.batching then
    (* Already in a batch, just run *)
    fn ()
  else begin
    rt.batching <- true;
    rt.pending_notifications <- [];
    let result = 
      try fn ()
      with e ->
        rt.batching <- false;
        rt.pending_notifications <- [];
        raise e
    in
    rt.batching <- false;
    (* Run all pending notifications *)
    let notifications = List.rev rt.pending_notifications in
    rt.pending_notifications <- [];
    List.iter (fun notify -> notify ()) notifications;
    result
  end
