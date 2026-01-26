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

module Spread = struct
  type t = {
    attrs : (string * string option) list;
    class_list : (string * bool) list;
    style : (string * string option) list;
  }

  type state = {
    mutable attrs : (string * string option) list;
    mutable class_list : (string * bool) list;
    mutable style : (string * string option) list;
  }

  let empty : t = { attrs = []; class_list = []; style = [] }

  let create_state () : state = { attrs = []; class_list = []; style = [] }

  let attrs attrs : t = { empty with attrs }
  let class_list class_list : t = { empty with class_list }
  let style style : t = { empty with style }

  let merge (a : t) (b : t) : t =
    { attrs = a.attrs @ b.attrs;
      class_list = a.class_list @ b.class_list;
      style = a.style @ b.style }

  let build_class_string class_list =
    class_list
    |> List.filter (fun (_name, enabled) -> enabled)
    |> List.map fst
    |> String.concat " "

  let build_style_string style =
    style
    |> List.filter_map (fun (name, value) -> Option.map (fun v -> name ^ ":" ^ v) value)
    |> String.concat ";"

  let apply ~set_attr ~element (state : state) (spread : t) =
    let prev_attr_keys = List.map fst state.attrs in
    let next_attr_keys = List.map fst spread.attrs in
    List.iter
      (fun key ->
        if not (List.mem key next_attr_keys) then set_attr element ~name:key None)
      prev_attr_keys;
    List.iter (fun (key, value) -> set_attr element ~name:key value) spread.attrs;

    let class_value = build_class_string spread.class_list in
    let class_value = if String.equal class_value "" then None else Some class_value in
    set_attr element ~name:"class" class_value;

    let style_value = build_style_string spread.style in
    let style_value = if String.equal style_value "" then None else Some style_value in
    set_attr element ~name:"style" style_value;

    state.attrs <- spread.attrs;
    state.class_list <- spread.class_list;
    state.style <- spread.style
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
  type spread = Spread.t

  val text : (unit -> string) -> 'a t
  val text_once : (unit -> string) -> 'a t
  val text_value : string -> 'a t
  val attr : name:string -> (unit -> string) -> 'a t
  val attr_opt : name:string -> (unit -> string option) -> 'a t
  val class_list : (unit -> (string * bool) list) -> 'a t
  val style : (unit -> (string * string option) list) -> 'a t

  val on :
    event:string
    -> ?capture:bool
    -> ?passive:bool
    -> ?once:bool
    -> ?prevent_default:bool
    -> ?stop_propagation:bool
    -> ('ev -> unit)
    -> ('ev -> unit) t

  val ref : ('el -> unit) -> 'a t
  val spread : (unit -> spread) -> 'a t

  val bind_input : signal:(unit -> string) -> setter:(string -> unit) -> 'a t
  val bind_checkbox : signal:(unit -> bool) -> setter:(bool -> unit) -> 'a t
  val bind_select : signal:(unit -> string) -> setter:(string -> unit) -> 'a t
  val bind_select_multiple : signal:(unit -> string list) -> setter:(string list -> unit) -> 'a t

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
  val dynamic : component:(unit -> ('props -> 'a)) -> ?props:(unit -> 'props) -> 'a t
  val portal : ?target:'el -> ?is_svg:bool -> render:(unit -> 'a) -> 'a t
  val suspense_list : render:(unit -> 'a) -> 'a t
  val deferred : render:(unit -> 'a) -> 'a t
  val transition : render:(unit -> 'a) -> 'a t
  val resource :
    resource:'r
    -> loading:(unit -> 'a)
    -> error:(string -> 'a)
    -> ready:('b -> 'a)
    -> 'a t
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
  [@@@warning "-16"]
  type 'a t =
    | Uncompiled of string

  let error name =
    "Solid_ml_template_runtime.Tpl." ^ name
    ^ " reached runtime. This means the template compiler did not rewrite this MLX tree.\n\n"
    ^ "Fix: ensure your dune stanza includes (preprocess (pps mlx solid-ml-template-ppx))."

  let text (_thunk : unit -> string) : 'a t =
    Uncompiled "text"

  let text_once (_thunk : unit -> string) : 'a t =
    Uncompiled "text_once"

  let text_value (_value : string) : 'a t =
    Uncompiled "text_value"

  let attr ~name (_thunk : unit -> string) : 'a t =
    Uncompiled ("attr(" ^ name ^ ")")

  let attr_opt ~name (_thunk : unit -> string option) : 'a t =
    Uncompiled ("attr_opt(" ^ name ^ ")")

  let class_list (_thunk : unit -> (string * bool) list) : 'a t =
    Uncompiled "class_list"

  let style (_thunk : unit -> (string * string option) list) : 'a t =
    Uncompiled "style"

  let on ~event ?capture:_ ?passive:_ ?once:_ ?prevent_default:_ ?stop_propagation:_
      (_handler : 'ev -> unit)
      : ('ev -> unit) t =
    Uncompiled ("on(" ^ event ^ ")")

  let ref (_handler : 'el -> unit) : 'a t =
    Uncompiled "ref"

  type spread = Spread.t

  let spread (_thunk : unit -> spread) : 'a t =
    Uncompiled "spread"

  let bind_input ~signal:_ ~setter:_ : 'a t =
    Uncompiled "bind_input"

  let bind_checkbox ~signal:_ ~setter:_ : 'a t =
    Uncompiled "bind_checkbox"

  let bind_select ~signal:_ ~setter:_ : 'a t =
    Uncompiled "bind_select"

  let bind_select_multiple ~signal:_ ~setter:_ : 'a t =
    Uncompiled "bind_select_multiple"

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

  let dynamic ~component ?props : 'a t =
    let _ = component in
    let _ = props in
    Uncompiled "dynamic"

  let portal ?target ?is_svg ~render:_ : 'a t =
    let _ = target in
    let _ = is_svg in
    Uncompiled "portal"

  let suspense_list ~render:_ : 'a t =
    Uncompiled "suspense_list"

  let deferred ~render:_ : 'a t =
    Uncompiled "deferred"

  let transition ~render:_ : 'a t =
    Uncompiled "transition"

  let resource ~resource:_ ~loading:_ ~error:_ ~ready:_ : 'a t =
    Uncompiled "resource"

  let suspense ~fallback:_ ~render:_ : 'a t =
    Uncompiled "suspense"

  let error_boundary ~fallback:_ ~render:_ : 'a t =
    Uncompiled "error_boundary"

  let unreachable (type a) (v : a t) : a =
    match v with
    | Uncompiled name -> invalid_arg (error name)
end
