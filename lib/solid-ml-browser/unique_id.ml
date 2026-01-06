(** Generate unique IDs for SSR hydration matching (browser version).
    
    This provides a way to generate unique IDs that are consistent between
    server and client rendering.
*)

(** Counter for generating unique IDs *)
let counter = ref 0

(** Create a new unique ID. *)
let create () =
  let id = !counter in
  incr counter;
  "solid-" ^ string_of_int id

(** Create a unique ID with a custom prefix. *)
let create_with_prefix prefix =
  let id = !counter in
  incr counter;
  prefix ^ "-" ^ string_of_int id

(** Reset the ID counter.
    
    Call this at the start of hydration to match server IDs. *)
let reset () =
  counter := 0

(** Get the current counter value without incrementing. *)
let peek () =
  !counter
