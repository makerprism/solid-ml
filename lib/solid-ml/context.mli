(** Component context for passing values down the tree.

    Context provides a way to pass data through the component tree without 
    having to pass props down manually at every level. This is useful for 
    sharing values like themes, user authentication, or localization.

    {[
      (* Create a context with a default value *)
      let theme_context = Context.create "light"

      (* Provide a value to descendants *)
      let app () =
        Context.provide theme_context "dark" (fun () ->
          (* All components here see "dark" theme *)
          child_component ()
        )

      (* Use the context value *)
      let child_component () =
        let theme = Context.use theme_context in
        print_endline ("Theme is: " ^ theme)
    ]}
*)

(** A context that can hold a value of type ['a]. *)
type 'a t

(** Create a new context with a default value.
    The default is used when [use] is called outside of any [provide].

    {[
      let user_context = Context.create None
      let theme_context = Context.create "light"
    ]}
*)
val create : 'a -> 'a t

(** Provide a value to all descendants.
    The value is available via [use] for the duration of [fn].

    {[
      Context.provide theme_context "dark" (fun () ->
        (* nested components can use theme_context *)
        render_children ()
      )
    ]}
*)
val provide : 'a t -> 'a -> (unit -> 'b) -> 'b

(** Use the current value of a context.
    Returns the nearest provided value, or the default if none.

    {[
      let theme = Context.use theme_context
    ]}
*)
val use : 'a t -> 'a
