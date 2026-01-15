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
      template's single root element.

      Compiled templates are expected to have exactly one root element so that
      paths are interpreted relative to the same node for CSR (instantiate) and
      hydration (hydrate).

      On SSR, this is a no-op wrapper around [instantiate]. *)

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

module Tpl : sig
  (** Marker surface for the template compiler.

      These helpers are meant to appear in MLX-authored code so the template PPX
      can recognize dynamic expressions.

      Real M3 requirement: without the template compiler, `Tpl.*` must fail at
      compile time (not at runtime).

      We achieve this by returning a distinct marker type ['a t] that cannot be
      unified with the normal Html/node/attr/event types. If any `Tpl.*` value
      makes it through compilation without being rewritten, the user will get a
      type error mentioning [Solid_ml_template_runtime.Tpl.t].

      When the template PPX is enabled, it rewrites `Tpl.*` markers away (the
      returned value is never used at runtime).
  *)

  type 'a t

  val text : (unit -> string) -> 'a t
  val attr : name:string -> (unit -> string) -> 'a t
  val attr_opt : name:string -> (unit -> string option) -> 'a t
  val class_list : (unit -> (string * bool) list) -> 'a t

  val on : event:string -> ('ev -> unit) -> ('ev -> unit) t

  val show : when_:(unit -> bool) -> (unit -> 'a) -> 'a t
  val each_keyed : items:(unit -> 'a list) -> key:('a -> string) -> render:('a -> 'b) -> 'b t

  val unreachable : 'a t -> 'a
  (** Defensive escape hatch.

      If you somehow manage to evaluate a `Tpl.*` marker at runtime (e.g. via
      `Obj.magic`), this raises with a clear message.
  *)
end = struct
  type 'a t =
    | Uncompiled of string

  let error name =
    "Solid_ml_template_runtime.Tpl." ^ name
    ^ " reached runtime. This means the template compiler did not rewrite this MLX tree.\n\n"
    ^ "Fix: ensure your dune stanza includes (preprocess (pps mlx solid-ml-template-ppx))."

  let text (_thunk : unit -> string) : 'a t =
    Uncompiled "text"

  let attr ~name (_thunk : unit -> string) : 'a t =
    Uncompiled ("attr(" ^ name ^ ")")

  let attr_opt ~name (_thunk : unit -> string option) : 'a t =
    Uncompiled ("attr_opt(" ^ name ^ ")")

  let class_list (_thunk : unit -> (string * bool) list) : 'a t =
    Uncompiled "class_list"

  let on ~event (_handler : 'ev -> unit) : ('ev -> unit) t =
    Uncompiled ("on(" ^ event ^ ")")

  let show ~when_:_ (_render : unit -> 'a) : 'a t =
    Uncompiled "show"

  let each_keyed ~items:_ ~key:_ ~render:_ : 'b t =
    Uncompiled "each_keyed"

  let unreachable (type a) (v : a t) : a =
    match v with
    | Uncompiled name -> invalid_arg (error name)
end
