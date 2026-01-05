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

    For server-side rendering with Dream or other frameworks,
    wrap each request in [Runtime.run]:

    {[
      let handler _req =
        Runtime.run (fun () ->
          let html = Render.to_string my_component in
          Dream.html html
        )
    ]}
*)

module Runtime = Runtime
module Signal = Signal
module Effect = Effect
module Memo = Memo
module Batch = Batch
module Owner = Owner
module Context = Context
