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
