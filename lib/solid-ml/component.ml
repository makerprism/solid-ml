(** Component abstraction for shared SSR/browser code.

    This module provides types for writing components that compile
    for both server-side rendering and browser execution.

    {1 Usage}

    Define a component as a functor over [COMPONENT_ENV]:

    {[
      (* shared/counter.ml *)
      module Counter (Env : Solid_ml.Component.COMPONENT_ENV) = struct
        open Env

        let render ~initial () =
          let count, set_count = Signal.create initial in
          Html.div ~children:[
            Html.p ~children:[Html.reactive_text count] ();
            Html.button ~onclick:(fun _ -> Signal.update count succ)
              ~children:[Html.text "+"] ()
          ] ()
      end
    ]}

    Then instantiate with the appropriate environment:

    {[
      (* server.ml - using SSR *)
      module ServerCounter = Counter(Solid_ml_ssr.Env)

      (* client.ml - using browser *)
      module BrowserCounter = Counter(Solid_ml_browser.Env)
    ]}
*)

(** {1 Signal Module Type} *)

module type SIGNAL = sig
  type 'a t
  (** A reactive signal holding a value of type ['a] *)

  val create : ?equals:('a -> 'a -> bool) -> 'a -> 'a t * ('a -> unit)
  (** Create a new signal with initial value. Returns (signal, setter).
      Optional [equals] for custom equality check. *)

  val get : 'a t -> 'a
  (** Read the current value and track as dependency. *)

  val peek : 'a t -> 'a
  (** Read the current value without tracking. *)

  val update : 'a t -> ('a -> 'a) -> unit
  (** Update signal with a function. *)
end

(** {1 Component Environment} *)

module type COMPONENT_ENV = sig
  module Signal : SIGNAL
  (** Signal module for reactive state. *)

  module Html : Html_intf.S with type 'a signal = 'a Signal.t
  (** Html module satisfying the unified interface.
      The signal type is unified with Signal.t. *)

  type 'a signal = 'a Signal.t
  (** Alias for signal type. *)
end

(** {2 Template Compiler Environment}

    The template compiler needs to generate shared code that attaches
    fine-grained bindings (effects + cleanup) in addition to reading signals.

    This environment is intentionally small; it is a superset of [COMPONENT_ENV]
    used only by compiled templates. *)

module type TEMPLATE_ENV = sig
  include COMPONENT_ENV

  module Effect : sig
    val create : (unit -> unit) -> unit
  end

  module Owner : sig
    val on_cleanup : (unit -> unit) -> unit
  end
end

