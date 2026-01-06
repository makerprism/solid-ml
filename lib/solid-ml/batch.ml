(** Batch multiple signal updates.
    
    Batching allows multiple signal updates to be grouped together,
    deferring effect execution until the batch completes. This prevents
    intermediate states from triggering unnecessary recomputation.
    
    In the new reactive system, updates are automatically batched
    within a single synchronous execution context. This module provides
    explicit batching for cases where you want to ensure updates are
    grouped together.
    
    Example:
    {[
      Batch.run (fun () ->
        set_name "Alice";
        set_age 30;
        set_city "NYC"
      )
      (* Effects observing name, age, or city only run once *)
    ]}
*)

(** Check if we're currently inside a batch *)
let is_batching () =
  match Reactive.get_runtime_opt () with
  | Some rt -> rt.in_update
  | None -> false

(** Run a function with batched updates.
    
    All signal updates within the function will be batched together.
    Effects and memos will only be updated once at the end of the batch.
    
    Batches can be nested - inner batches are merged with outer ones. *)
let run fn =
  Reactive.run_updates fn false
