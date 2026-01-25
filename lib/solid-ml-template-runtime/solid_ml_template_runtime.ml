(** Shared runtime interfaces for solid-ml template compilation.

    This package is intended to support a SolidJS-style template compiler:
    - Templates are precompiled at build time into a static structure
    - At runtime, templates are instantiated (cloned) and bindings are attached

    The concrete runtime implementation lives in the SSR and browser Html
    backends. This package only provides module types and shared definitions.
*)

module Template_intf = Template_intf
module Env_intf = Env_intf

include Template_intf

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
  val text_value : string -> 'a t
  val attr : name:string -> (unit -> string) -> 'a t
  val attr_opt : name:string -> (unit -> string option) -> 'a t
  val class_list : (unit -> (string * bool) list) -> 'a t

  val on : event:string -> ('ev -> unit) -> ('ev -> unit) t

  val bind_input : signal:(unit -> string) -> setter:(string -> unit) -> 'a t
  val bind_checkbox : signal:(unit -> bool) -> setter:(bool -> unit) -> 'a t
  val bind_select : signal:(unit -> string) -> setter:(string -> unit) -> 'a t

  val nodes : (unit -> 'a) -> 'a t
  (** Marker for a dynamic child region (control flow).

      The template PPX rewrites this into `Template.bind_nodes` + `Template.set_nodes`. *)

  val show : when_:(unit -> bool) -> (unit -> 'a) -> 'a t
  val show_when : when_:(unit -> bool) -> (unit -> 'a) -> 'a t
  val if_ : when_:(unit -> bool) -> then_:(unit -> 'a) -> else_:(unit -> 'a) -> 'a t
  val switch : match_:(unit -> 'a) -> cases:(('a -> bool) * (unit -> 'b)) array -> 'b t
  val each_keyed : items:(unit -> 'a list) -> key:('a -> string) -> render:('a -> 'b) -> 'b t
  val each : items:(unit -> 'a list) -> render:('a -> 'b) -> 'b t
  val eachi : items:(unit -> 'a list) -> render:(int -> 'a -> 'b) -> 'b t
  val each_indexed :
    items:(unit -> 'a list)
    -> render:(index:(unit -> int) -> item:(unit -> 'a) -> 'b)
    -> 'b t
  val suspense : fallback:(unit -> 'a) -> render:(unit -> 'a) -> 'a t
  val error_boundary :
    fallback:(error:string -> reset:(unit -> unit) -> 'a)
    -> render:(unit -> 'a)
    -> 'a t

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

  let text_value (_value : string) : 'a t =
    Uncompiled "text_value"

  let attr ~name (_thunk : unit -> string) : 'a t =
    Uncompiled ("attr(" ^ name ^ ")")

  let attr_opt ~name (_thunk : unit -> string option) : 'a t =
    Uncompiled ("attr_opt(" ^ name ^ ")")

  let class_list (_thunk : unit -> (string * bool) list) : 'a t =
    Uncompiled "class_list"

  let on ~event (_handler : 'ev -> unit) : ('ev -> unit) t =
    Uncompiled ("on(" ^ event ^ ")")

  let bind_input ~signal:_ ~setter:_ : 'a t =
    Uncompiled "bind_input"

  let bind_checkbox ~signal:_ ~setter:_ : 'a t =
    Uncompiled "bind_checkbox"

  let bind_select ~signal:_ ~setter:_ : 'a t =
    Uncompiled "bind_select"

  let nodes (_thunk : unit -> 'a) : 'a t =
    Uncompiled "nodes"

  let show ~when_:_ (_render : unit -> 'a) : 'a t =
    Uncompiled "show"

  let show_when ~when_:_ (_render : unit -> 'a) : 'a t =
    Uncompiled "show_when"

  let if_ ~when_:_ ~then_:_ ~else_:_ : 'a t =
    Uncompiled "if_"

  let switch ~match_:_ ~cases:_ : 'b t =
    Uncompiled "switch"

  let each_keyed ~items:_ ~key:_ ~render:_ : 'b t =
    Uncompiled "each_keyed"

  let each ~items:_ ~render:_ : 'b t =
    Uncompiled "each"

  let eachi ~items:_ ~render:_ : 'b t =
    Uncompiled "eachi"

  let each_indexed ~items:_ ~render:_ : 'b t =
    Uncompiled "each_indexed"

  let suspense ~fallback:_ ~render:_ : 'a t =
    Uncompiled "suspense"

  let error_boundary ~fallback:_ ~render:_ : 'a t =
    Uncompiled "error_boundary"

  let unreachable (type a) (v : a t) : a =
    match v with
    | Uncompiled name -> invalid_arg (error name)
end
