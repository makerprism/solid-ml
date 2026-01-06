(** Generate unique IDs for SSR hydration matching.
    
    This provides a way to generate unique IDs that are consistent between
    server and client rendering, enabling proper hydration of elements that
    need stable IDs (like form labels, ARIA attributes, etc.).
    
    {[
      let label_id = Unique_id.create () in
      Html.label ~for_:label_id ~children:[Html.text "Name"] ();
      Html.input ~id:label_id ~type_:"text" ()
    ]}
    
    {2 SSR Considerations}
    
    For IDs to match between server and client:
    - Call [reset ()] at the start of each render (both server and client)
    - IDs must be generated in the same order on both sides
    
    {[
      (* In your SSR handler *)
      Unique_id.reset ();
      let html = Render.to_string my_component in
      
      (* In your client hydration *)
      Unique_id.reset ();
      Render.hydrate root my_component
    ]}
*)

(** Counter for generating unique IDs *)
let counter = ref 0

(** Create a new unique ID.
    
    Returns a string like "solid-0", "solid-1", etc. *)
let create () =
  let id = !counter in
  incr counter;
  "solid-" ^ string_of_int id

(** Create a unique ID with a custom prefix.
    
    Returns a string like "my-prefix-0", "my-prefix-1", etc. *)
let create_with_prefix prefix =
  let id = !counter in
  incr counter;
  prefix ^ "-" ^ string_of_int id

(** Reset the ID counter.
    
    Call this at the start of each render to ensure IDs match
    between server and client. *)
let reset () =
  counter := 0

(** Get the current counter value without incrementing.
    
    Useful for debugging or testing. *)
let peek () =
  !counter
