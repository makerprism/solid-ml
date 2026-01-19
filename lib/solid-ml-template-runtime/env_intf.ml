(** Minimal environment interface used by the template compiler.

    This lives in [solid-ml-template-runtime] so both SSR and browser packages can
    expose a canonical environment without introducing a dependency on the core
    [solid-ml] package.

    The template compiler only needs:
    - a signal type with basic operations
    - an Html.Template backend for instantiation/binding
    - Effect.create for fine-grained reactive updates
    - Owner.on_cleanup for disposal (events, conditional mounts, lists)

    Note: this interface is intentionally smaller than [Solid_ml.Component.COMPONENT_ENV]
    and does not depend on [Solid_ml.Html_intf.S]. Compiled templates should not
    need to call element constructors at runtime; they instantiate precompiled
    templates via [Html.Template].
*)

module type SIGNAL = sig
  type 'a t

  val create : ?equals:('a -> 'a -> bool) -> 'a -> 'a t * ('a -> unit)
  val get : 'a t -> 'a
  val peek : 'a t -> 'a
  val update : 'a t -> ('a -> 'a) -> unit
end

module type HTML = sig
  type node
  type event
  type 'a signal

  val text : string -> node
  val fragment : node list -> node
  val empty : node

  (* Note: we intentionally do not expose element constructors here.
     User code using MLX intrinsics should use the platform-specific Html API.

     The only required constructors are [text], [fragment], and [empty]. *)

  module Internal_template : Template_intf.TEMPLATE
    with type node := node
     and type event := event
end

module type TEMPLATE_ENV = sig
  module Signal : SIGNAL
  type 'a signal = 'a Signal.t

  module Html : HTML with type 'a signal = 'a Signal.t

  module Effect : sig
    val create : (unit -> unit) -> unit
    val create_with_cleanup : (unit -> (unit -> unit)) -> unit
  end

  module Owner : sig
    val on_cleanup : (unit -> unit) -> unit

    val run_with_owner : (unit -> 'a) -> 'a * (unit -> unit)
    (** Run a function under a fresh owner.

        Returns the function result and a disposer that cleans up any effects,
        event handlers, and other resources registered under that owner. *)
  end
end
