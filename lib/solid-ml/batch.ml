(** Batch multiple signal updates.

    Note: This is a simplified implementation. A full implementation
    would require modifying Signal to defer notifications during batching.
    For now, this just runs the function - batching will be implemented
    when we add the notification queue to Signal.
*)

let batching = ref false
let pending_notifications : (unit -> unit) list ref = ref []

let is_batching () = !batching

let run fn =
  if !batching then
    (* Already in a batch, just run *)
    fn ()
  else begin
    batching := true;
    pending_notifications := [];
    let result = fn () in
    batching := false;
    (* Run all pending notifications *)
    List.iter (fun notify -> notify ()) !pending_notifications;
    pending_notifications := [];
    result
  end

(** Queue a notification (called by Signal during batching).
    Exported for use by Signal module. *)
let queue_notification notify =
  if !batching then
    pending_notifications := notify :: !pending_notifications
  else
    notify ()
