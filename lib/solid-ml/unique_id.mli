(** Generate unique IDs for SSR hydration matching.
    
    This provides a way to generate unique IDs that are consistent between
    server and client rendering, enabling proper hydration of elements that
    need stable IDs.
    
    {2 Common Use Cases}
    
    - Form labels and inputs (matching [for] and [id] attributes)
    - ARIA attributes ([aria-labelledby], [aria-describedby])
    - Any element that needs a stable, unique identifier
    
    {2 Usage}
    
    {[
      let label_id = Unique_id.create () in
      Html.label ~for_:label_id ~children:[Html.text "Name"] ();
      Html.input ~id:label_id ~type_:"text" ()
    ]}
    
    {2 SSR Considerations}
    
    For IDs to match between server and client:
    - Call [reset ()] at the start of each render
    - Generate IDs in the same order on both sides
*)

(** Create a new unique ID.
    
    Returns a string like "solid-0", "solid-1", etc. *)
val create : unit -> string

(** Create a unique ID with a custom prefix.
    
    Returns a string like "prefix-0", "prefix-1", etc. *)
val create_with_prefix : string -> string

(** Reset the ID counter.
    
    Call this at the start of each render to ensure IDs match
    between server and client. *)
val reset : unit -> unit

(** Get the current counter value without incrementing. *)
val peek : unit -> int
