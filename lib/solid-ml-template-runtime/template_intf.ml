(** Internal template interfaces.

    This module exists so other modules in the wrapped library (e.g. [Env_intf])
    can depend on the template signatures without depending on the library's main
    module ([Solid_ml_template_runtime]).
*)

(** Template slot kind.

    A template compiler will typically model all dynamic values as "slots" that
    are filled at runtime.

    - [`Text] slots represent text-node content
    - [`Attr] slots represent attribute values (already quoted in the template)
    - [`Nodes] slots represent a dynamic child region (control flow)
*)

type slot_kind = [ `Text | `Attr | `Nodes ]

module type TEMPLATE = sig
  type node
  type event

  type template
  type instance

  type text_slot
  type nodes_slot
  type element

  val compile : segments:string array -> slot_kinds:slot_kind array -> template
  (** Compile a template from static [segments] and per-slot [slot_kinds].

      Invariant: [Array.length segments = Array.length slot_kinds + 1].

      The compiler emits [segments] such that slot [i] is inserted between
      [segments.(i)] and [segments.(i + 1)]. *)

  val instantiate : template -> instance
  (** Instantiate (clone) a template for client-side rendering. *)

  (* Note: hydration adoption is intentionally not exposed here.

     Compiled templates should be adopted via the framework-level hydration entrypoint
     (e.g. [Solid_ml_browser.Render.hydrate]), which establishes a structured
     hydration lifetime and configures adoption state.

     Template instantiation/binding APIs must work correctly when called within
     hydration mode, but the operation of "adopting" an existing DOM subtree is
     framework-specific. *)

  val root : instance -> node
  (** Return the root node for the instance.

      For browser CSR/hydration, this should be the single root element.
      (Templates with multiple top-level nodes are intentionally unsupported in
      v1 because they make path-based hydration ambiguous.) *)

  val bind_text : instance -> id:int -> path:int array -> text_slot
  (** Bind a template text slot.

      [id] is a compiler-assigned slot id.

      [path] is interpreted as an *insertion path* for text, relative to the
      instance root element:
      - All but the last index locate the parent node
      - The last index is the child insertion index

      The browser backend must create the text node if it does not exist.
      The SSR backend may ignore [path]. *)

  val set_text : text_slot -> string -> unit
  (** Set the text content for a bound text slot. *)

  val bind_nodes : instance -> id:int -> path:int array -> nodes_slot
  (** Bind a dynamic child-region slot.

      [path] is an insertion path. The compiler typically points at the *closing*
      marker node for the region (e.g. the second `<!--$-->`).

      The browser backend should treat the region as everything between the
      matching marker pair.

      The SSR backend may ignore [path]. *)

  val set_nodes : nodes_slot -> node -> unit
  (** Replace the region contents with the given node.

      Use a fragment node to insert multiple children, and an empty fragment to
      clear the region. *)

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

  val off_ : element -> event:string -> (event -> unit) -> unit
  (** Detach an event handler.

      This is primarily used by compiled templates for cleanup.
      On SSR, this is a no-op. *)

  val set_nodes_keyed :
    nodes_slot -> key:('a -> string) -> render:('a -> node * (unit -> unit)) -> 'a list -> unit
  (** Set a nodes region to a keyed list.

      Browser backends should reconcile DOM nodes by key when possible.
      SSR backends may render the list to HTML and replace the region.

      Note: disposal of per-item reactive resources is managed by the caller
      (typically the template compiler) via the owner tree. *)
end
