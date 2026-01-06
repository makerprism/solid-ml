(** Component context for passing values down the tree.
    
    Context values are stored on Owner nodes, enabling proper
    isolation between concurrent renders and correct shadowing
    in nested component trees.
    
    This is similar to React's Context API or SolidJS's context.
    
    {[
      let theme_context = Context.create "light"
      
      let app () =
        Context.provide theme_context "dark" (fun () ->
          (* All components here see "dark" theme *)
          let theme = Context.use theme_context in
          print_endline theme  (* "dark" *)
        )
    ]}
*)

(** A context holds a default value and unique ID *)
type 'a t

(** Create a new context with a default value.
    
    The default is used when [use] is called outside of any
    [provide] scope for this context. *)
val create : 'a -> 'a t

(** Use (read) a context value.
    
    Looks up the owner tree for a provided value.
    Returns the default if no value was provided. *)
val use : 'a t -> 'a

(** Provide a context value for a scope.
    
    All [use] calls within [fn] (and its descendants) will
    see the provided value instead of the default.
    
    Context values can be shadowed by nested [provide] calls. *)
val provide : 'a t -> 'a -> (unit -> 'b) -> 'b
