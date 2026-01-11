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
      module ServerEnv = struct
        module Html = Solid_ml_ssr.Html
        module Signal = Solid_ml.Signal
        type 'a signal = 'a Signal.t
      end
      module ServerCounter = Counter(ServerEnv)

      (* client.ml - using browser *)
      module BrowserEnv = struct
        module Html = Solid_ml_browser.Html
        module Signal = Solid_ml_browser.Reactive.Signal
        type 'a signal = 'a Signal.t
      end
      module BrowserCounter = Counter(BrowserEnv)
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

(** {1 SSR Environment}

    Pre-built environment for server-side rendering.
    Use this when instantiating components on the server. *)

module Ssr_env : COMPONENT_ENV = struct
  type 'a signal = 'a Signal.t

  module Signal = struct
    type 'a t = 'a signal
    let create ?equals = Signal.create ?equals
    let get = Signal.get
    let peek = Signal.peek
    let update = Signal.update
  end

  module Html = struct
    type node = unit  (* Placeholder - actual impl provided by solid-ml-ssr *)
    type 'a signal = 'a Signal.t
    type event = unit  (* SSR events are stubs *)

    (* All functions are stubs here - the real SSR Html will be used *)
    let text _ = ()
    let int _ = ()
    let float _ = ()
    let fragment _ = ()
    let reactive_text _ = ()
    let reactive_text_of _ _ = ()
    let reactive_text_string _ = ()
    let div ?id:_ ?class_:_ ?style:_ ?onclick:_ ~children:_ () = ()
    let span ?id:_ ?class_:_ ?style:_ ?onclick:_ ~children:_ () = ()
    let p ?id:_ ?class_:_ ?onclick:_ ~children:_ () = ()
    let pre ?id:_ ?class_:_ ~children:_ () = ()
    let code ?id:_ ?class_:_ ~children:_ () = ()
    let h1 ?id:_ ?class_:_ ?onclick:_ ~children:_ () = ()
    let h2 ?id:_ ?class_:_ ?onclick:_ ~children:_ () = ()
    let h3 ?id:_ ?class_:_ ?onclick:_ ~children:_ () = ()
    let h4 ?id:_ ?class_:_ ?onclick:_ ~children:_ () = ()
    let h5 ?id:_ ?class_:_ ?onclick:_ ~children:_ () = ()
    let h6 ?id:_ ?class_:_ ?onclick:_ ~children:_ () = ()
    let header ?id:_ ?class_:_ ~children:_ () = ()
    let footer ?id:_ ?class_:_ ~children:_ () = ()
    let main ?id:_ ?class_:_ ~children:_ () = ()
    let nav ?id:_ ?class_:_ ~children:_ () = ()
    let section ?id:_ ?class_:_ ~children:_ () = ()
    let article ?id:_ ?class_:_ ~children:_ () = ()
    let aside ?id:_ ?class_:_ ~children:_ () = ()
    let a ?id:_ ?class_:_ ?href:_ ?target:_ ?onclick:_ ~children:_ () = ()
    let strong ?id:_ ?class_:_ ~children:_ () = ()
    let em ?id:_ ?class_:_ ~children:_ () = ()
    let br () = ()
    let hr ?class_:_ () = ()
    let ul ?id:_ ?class_:_ ~children:_ () = ()
    let ol ?id:_ ?class_:_ ?start:_ ~children:_ () = ()
    let li ?id:_ ?class_:_ ?onclick:_ ~children:_ () = ()
    let table ?id:_ ?class_:_ ~children:_ () = ()
    let thead ~children:_ () = ()
    let tbody ~children:_ () = ()
    let tfoot ~children:_ () = ()
    let tr ?class_:_ ~children:_ () = ()
    let th ?class_:_ ?scope:_ ?colspan:_ ?rowspan:_ ~children:_ () = ()
    let td ?class_:_ ?colspan:_ ?rowspan:_ ~children:_ () = ()
    let form ?id:_ ?class_:_ ?action:_ ?method_:_ ?enctype:_ ?onsubmit:_ ~children:_ () = ()
    let input ?id:_ ?class_:_ ?type_:_ ?name:_ ?value:_ ?placeholder:_
        ?required:_ ?disabled:_ ?checked:_ ?autofocus:_ ?oninput:_ ?onchange:_ ?onkeydown:_ () = ()
    let textarea ?id:_ ?class_:_ ?name:_ ?placeholder:_ ?rows:_ ?cols:_
        ?required:_ ?disabled:_ ?oninput:_ ~children:_ () = ()
    let select ?id:_ ?class_:_ ?name:_ ?required:_ ?disabled:_ ?multiple:_
        ?onchange:_ ~children:_ () = ()
    let option ?value:_ ?selected:_ ?disabled:_ ~children:_ () = ()
    let label ?id:_ ?class_:_ ?for_:_ ~children:_ () = ()
    let button ?id:_ ?class_:_ ?type_:_ ?disabled:_ ?onclick:_ ~children:_ () = ()
    let img ?id:_ ?class_:_ ?src:_ ?alt:_ ?width:_ ?height:_ ?loading:_ () = ()
  end
end
