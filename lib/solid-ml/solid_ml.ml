(** solid-ml: Fine-grained reactivity for OCaml.

    {[
      open Solid_ml

      let counter () =
        let count, set_count = Signal.create 0 in
        
        Effect.create (fun () ->
          print_endline ("Count: " ^ string_of_int (Signal.get count))
        );
        
        set_count 1;  (* prints "Count: 1" *)
        set_count 2   (* prints "Count: 2" *)
    ]}
*)

module Signal = Signal
module Effect = Effect
module Memo = Memo
module Batch = Batch
