(** Shared runtime interfaces for solid-ml template compilation.

    This package is intended to support a SolidJS-style template compiler:
    - Templates are precompiled at build time into a static structure
    - At runtime, templates are instantiated (cloned) and bindings are attached

    The concrete runtime implementation lives in the SSR and browser Html
    backends. This package only provides module types and shared definitions.
*)

(** Template slot kind.

    A template compiler will typically model all dynamic values as "slots"
    that are filled at runtime.

    - [`Text] slots represent text-node content
    - [`Attr] slots represent attribute values (already quoted in the template)
*)

type slot_kind = [ `Text | `Attr ]

module type TEMPLATE = sig
  type node
  type event

  type template
  type instance

  type text_slot
  type element

  val compile : segments:string array -> slot_kinds:slot_kind array -> template
  (** Compile a template from static [segments] and per-slot [slot_kinds].

      Invariant: [Array.length segments = Array.length slot_kinds + 1].

      The compiler emits [segments] such that slot [i] is inserted between
      [segments.(i)] and [segments.(i + 1)]. *)

  val instantiate : template -> instance
  (** Instantiate (clone) a template for client-side rendering. *)

  val hydrate : root:element -> template -> instance
  (** Adopt existing DOM for hydration.

      On the browser, [root] is the DOM element that corresponds to the
      template's root.

      On SSR, this is a no-op wrapper around [instantiate]. *)

  val root : instance -> node
  (** Return the root node for the instance. *)

  val bind_text : instance -> id:int -> path:int array -> text_slot
  (** Bind a template text slot.

      [id] is a compiler-assigned slot id.

      [path] is interpreted as an *insertion path* for text:
      - All but the last index locate the parent node
      - The last index is the child insertion index

      The browser backend must create the text node if it does not exist.
      The SSR backend may ignore [path]. *)

  val set_text : text_slot -> string -> unit
  (** Set the text content for a bound text slot. *)

  val bind_element : instance -> id:int -> path:int array -> element
  (** Bind a template element handle.

      [id] is a compiler-assigned id for diagnostics/debugging.
      [path] locates the element within the instantiated DOM.
      The SSR backend may ignore [path]. *)

  val set_attr : element -> name:string -> string option -> unit
  (** Set or remove an attribute on an element. *)

  val on_ : element -> event:string -> (event -> unit) -> unit
  (** Attach an event handler.

      On SSR, event handlers are ignored. *)
end
