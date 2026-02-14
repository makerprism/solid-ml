open Ppxlib

let known_tpl_markers =
  [ "text";
    "text_once";
    "text_value";
    "nodes";
    "attr";
    "attr_opt";
    "class_list";
    "style";
    "on";
    "ref";
    "spread";
    "bind_input";
    "bind_checkbox";
    "bind_select";
    "bind_select_multiple";
    "show";
    "show_when";
    "show_value";
    "if_";
    "switch";
    "each_keyed";
    "each";
    "eachi";
    "each_indexed";
    "dynamic";
    "portal";
    "suspense_list";
    "deferred";
    "transition";
    "resource";
    "suspense";
    "error_boundary"
  ]

let is_known_marker fn = List.exists (String.equal fn) known_tpl_markers


let longident_to_list (longident : Longident.t) : string list =
  let rec go acc = function
    | Longident.Lident s -> s :: acc
    | Longident.Ldot (t, s) -> go (s :: acc) t
    | Longident.Lapply _ -> acc
  in
  go [] longident

let is_tpl_module_path = function
  | [ "Solid_ml_template_runtime"; "Tpl" ] -> true
  | [ "Tpl" ] -> true
  | _ -> false

let collect_tpl_aliases (structure : Parsetree.structure) : string list =
  let aliases = ref [] in
  let add name =
    if List.exists (String.equal name) !aliases then () else aliases := name :: !aliases
  in
  (* Collect direct aliases to Tpl, then close over simple alias chains.

     This is intentionally shallow: we only look at top-level module aliases of
     the form [module X = Y]. *)
  let pass () =
    let changed = ref false in
    List.iter
      (fun item ->
        match item.pstr_desc with
        | Pstr_module { pmb_name = { txt = Some name; _ }; pmb_expr; _ } ->
          (match pmb_expr.pmod_desc with
           | Pmod_ident { txt = longident; _ } ->
             (match longident_to_list longident with
              | path when is_tpl_module_path path ->
                if not (List.exists (String.equal name) !aliases) then (
                  add name;
                  changed := true)
              | [ alias ] when List.exists (String.equal alias) !aliases ->
                if not (List.exists (String.equal name) !aliases) then (
                  add name;
                  changed := true)
              | _ -> ())
           | _ -> ())
        | _ -> ())
      structure;
    !changed
  in
  (* Guardrail: avoid pathological alias chains. *)
  let rec loop remaining =
    if remaining = 0 then ()
    else if pass () then loop (remaining - 1)
    else ()
  in
  loop 16;
  !aliases

let collect_html_opens (structure : Parsetree.structure) : bool =
  let opened = ref false in
  let is_html longident =
    match List.rev (longident_to_list longident) with
    | "Html" :: _ -> true
    | _ -> false
  in
  let iter =
    object
      inherit Ast_traverse.iter as super

      method! structure_item item =
        (match item.pstr_desc with
         | Pstr_open { popen_expr = { pmod_desc = Pmod_ident { txt = longident; _ }; _ }; _ } ->
           if is_html longident then opened := true
         | _ -> ());
        super#structure_item item
    end
  in
  iter#structure structure;
  !opened

let structure_uses_unqualified_text (structure : Parsetree.structure) : bool =
  let uses = ref false in
  let rec head_ident = function
    | { Parsetree.pexp_desc = Pexp_ident { txt = longident; _ }; _ } -> Some longident
    | { Parsetree.pexp_desc = Pexp_apply (fn, _); _ } -> head_ident fn
    | _ -> None
  in
  let iter =
    object
      inherit Ast_traverse.iter as super

      method! expression expr =
        (match expr.pexp_desc with
         | Pexp_apply _ ->
           (match head_ident expr with
            | Some longident ->
              (match longident_to_list longident with
               | [ "text" ] -> uses := true
               | _ -> ())
            | None -> ())
         | _ -> ());
        super#expression expr
    end
  in
  iter#structure structure;
  !uses

let contains_substring (s : string) (sub : string) : bool =
  let len = String.length s in
  let sub_len = String.length sub in
  let rec loop idx =
    if idx + sub_len > len then false
    else if String.sub s idx sub_len = sub then true
    else loop (idx + 1)
  in
  if sub_len = 0 then true else loop 0

let warning_attr_includes_unused_open (attr : Parsetree.attribute) : bool =
  if not (String.equal attr.attr_name.txt "warning") then false
  else
    match attr.attr_payload with
    | PStr [ { pstr_desc = Pstr_eval ({ pexp_desc = Pexp_constant (Pconst_string (s, _, _)); _ }, _); _ } ] ->
      contains_substring s "-33"
    | _ -> false

let add_unused_open_warning_to_html_opens (structure : Parsetree.structure) : Parsetree.structure =
  let is_html_open (open_decl : Parsetree.open_declaration) : bool =
    match open_decl.popen_expr.pmod_desc with
    | Pmod_ident { txt = longident; _ } ->
      (match List.rev (longident_to_list longident) with
       | "Html" :: _ -> true
       | _ -> false)
    | _ -> false
  in
  let warning_attr ~loc =
    let open Ast_builder.Default in
    { attr_name = { loc; txt = "warning" };
      attr_payload = PStr [ pstr_eval ~loc (estring ~loc "-33") [] ];
      attr_loc = loc }
  in
  let mapper =
    object
      inherit Ast_traverse.map as super

      method! structure_item item =
        let item =
          match item.pstr_desc with
          | Pstr_open open_decl when is_html_open open_decl ->
            let attrs = open_decl.popen_attributes in
            if List.exists warning_attr_includes_unused_open attrs then item
            else
              let open_decl =
                { open_decl with
                  popen_attributes = warning_attr ~loc:open_decl.popen_loc :: attrs }
              in
              { item with pstr_desc = Pstr_open open_decl }
          | _ -> item
        in
        super#structure_item item
    end
  in
  mapper#structure structure

let structure_defines_text (structure : Parsetree.structure) : bool =
  let defines = ref false in
  let rec has_text_pattern (pat : Parsetree.pattern) : bool =
    match pat.ppat_desc with
    | Ppat_var { txt = "text"; _ } -> true
    | Ppat_alias (inner, { txt = "text"; _ }) -> has_text_pattern inner || true
    | Ppat_tuple pats -> List.exists has_text_pattern pats
    | Ppat_record (fields, _) -> List.exists (fun (_, p) -> has_text_pattern p) fields
    | Ppat_array pats -> List.exists has_text_pattern pats
    | Ppat_construct (_, Some (_args, p)) -> has_text_pattern p
    | Ppat_or (p1, p2) -> has_text_pattern p1 || has_text_pattern p2
    | Ppat_constraint (p, _) -> has_text_pattern p
    | Ppat_lazy p -> has_text_pattern p
    | _ -> false
  in
  let iter =
    object
      inherit Ast_traverse.iter as super

      method! value_binding vb =
        if has_text_pattern vb.pvb_pat then defines := true;
        super#value_binding vb

      method! expression expr =
        (match expr.pexp_desc with
         | Pexp_let (_, bindings, _) ->
           if List.exists (fun vb -> has_text_pattern vb.pvb_pat) bindings then
             defines := true
         | _ -> ());
        super#expression expr
    end
  in
  iter#structure structure;
  !defines

let tpl_marker_name ~(aliases : string list) (longident : Longident.t) : string option =
  match longident_to_list longident with
  | [ "Solid_ml_template_runtime"; "Tpl"; fn ] when is_known_marker fn -> Some fn
  | [ "Tpl"; fn ] when is_known_marker fn -> Some fn
  | [ alias; fn ] when is_known_marker fn && List.exists (String.equal alias) aliases -> Some fn
  | _ -> None


let head_ident (expr : Parsetree.expression) : Longident.t option =
  let rec go = function
    | { Parsetree.pexp_desc = Pexp_ident { txt = longident; _ }; _ } -> Some longident
    | { Parsetree.pexp_desc = Pexp_apply (fn, _); _ } -> go fn
    | _ -> None
  in
  go expr

let tpl_marker_of_expr ~(aliases : string list) (expr : Parsetree.expression) : string option =
  let rec strip expr =
    match expr.pexp_desc with
    | Pexp_constraint (inner, _) -> strip inner
    | Pexp_coerce (inner, _, _) -> strip inner
    | _ -> expr
  in
  match head_ident (strip expr) with
  | None -> None
  | Some longident -> tpl_marker_name ~aliases longident


let contains_tpl_markers (structure : Parsetree.structure) : (Location.t * string) option =
  let aliases = collect_tpl_aliases structure in
  let found = ref None in
  let record loc name =
    match !found with
    | None -> found := Some (loc, name)
    | Some _ -> ()
  in
  let iter =
    object
      inherit Ast_traverse.iter as super

      method! expression expr =
        (* Only flag actual marker *uses* (calls), not bare identifiers.
           This reduces false positives in non-template helper code. *)
        (match expr.pexp_desc with
         | Pexp_apply _ ->
           (match head_ident expr with
            | None -> ()
            | Some longident ->
              (match tpl_marker_name ~aliases longident with
               | Some name -> record expr.pexp_loc name
               | None -> ()))
         | _ -> ());
        super#expression expr
    end
  in
  iter#structure structure;
  !found

 let supported_subset =
    "<tag> (or Html.<tag>) ~children:[text/Html.text \"<literal>\"; Html.text <expr> (non-reactive); Tpl.text_once (fun () -> ...); Tpl.text (fun () -> ...); Tpl.text_value <value>; Tpl.show/_when/if_/switch/suspense_list/suspense/error_boundary/dynamic/portal/deferred/transition/resource ...; Tpl.each/eachi/each_indexed/each_keyed ...; <tag>/Html.<tag> ...; ...] ()\n\
     - supports nested intrinsic tags in children\n\
     - emits `<!--#-->` comment markers before text slots (SolidJS-style) to stabilize DOM paths\n\
     - emits `<!--$-->` markers for dynamic node regions\n\
     - ignores formatting-only whitespace Html.text literals containing newlines/tabs (except under <pre>/<code>)\n\
     - supports static ~id:\"...\" and ~class_:\"...\"\n\
     - supports dynamic labelled args (e.g. ~class_:(fun () -> ...)) and Tpl.attr/Tpl.attr_opt\n\
     - supports Tpl.on, Tpl.class_list, Tpl.bind_input/bind_checkbox/bind_select/bind_select_multiple in labelled args\n\
     - no other props; <tag> in {div,span,p,a,button,form,input,label,textarea,select,option,ul,li,strong,em,section,main,header,footer,nav,pre,code,h1..h6}\n\
     \n\
     For JSX syntax help, see: https://github.com/makerprism/solid-ml/blob/main/README.md#mlx-dialect-jsx-like-syntax"


let rec list_of_expr (expr : Parsetree.expression) : Parsetree.expression list option =
  match expr.pexp_desc with
  | Pexp_construct ({ txt = Longident.Lident "[]"; _ }, None) -> Some []
  | Pexp_construct
      ({ txt = Longident.Lident "::"; _ },
       Some { pexp_desc = Pexp_tuple [ hd; tl ]; _ }) ->
    (match list_of_expr tl with
     | None -> None
     | Some rest -> Some (hd :: rest))
  | _ -> None

let is_unit_expr (expr : Parsetree.expression) : bool =
  match expr.pexp_desc with
  | Pexp_construct ({ txt = Longident.Lident "()"; _ }, None) -> true
  | _ -> false

let supported_intrinsic_tags =
  [
    "html";
    "head";
    "body";
    "title";
    "meta";
    "link";
    "script";
    "header";
    "footer";
    "main";
    "nav";
    "section";
    "article";
    "aside";
    "figure";
    "figcaption";
    "address";
    "details";
    "summary";
    "div";
    "span";
    "p";
    "a";
    "button";
    "pre";
    "code";
    "blockquote";
    "strong";
    "em";
    "b";
    "i";
    "u";
    "s";
    "small";
    "mark";
    "sup";
    "sub";
    "cite";
    "q";
    "abbr";
    "data";
    "time";
    "kbd";
    "samp";
    "var";
    "del";
    "ins";
    "form";
    "fieldset";
    "legend";
    "input";
    "label";
    "textarea";
    "select";
    "option";
    "optgroup";
    "output";
    "progress";
    "meter";
    "ul";
    "ol";
    "li";
    "dl";
    "dt";
    "dd";
    "table";
    "caption";
    "colgroup";
    "col";
    "thead";
    "tbody";
    "tfoot";
    "tr";
    "th";
    "td";
    "img";
    "br";
    "hr";
    "picture";
    "source";
    "track";
    "video";
    "audio";
    "h1";
    "h2";
    "h3";
    "h4";
    "h5";
    "h6";
  ]

let is_supported_intrinsic_tag tag =
  List.exists (String.equal tag) supported_intrinsic_tags

let self_closing_intrinsic_tags = [ "input"; "img"; "br"; "hr"; "meta"; "link"; "source"; "track"; "col" ]

let is_self_closing_intrinsic_tag tag =
  List.exists (String.equal tag) self_closing_intrinsic_tags

let extract_intrinsic_tag (longident : Longident.t) : string option =
  match List.rev (longident_to_list longident) with
  | tag :: _ when is_supported_intrinsic_tag tag -> Some tag
  | _ -> None

  type attr_binding = {
    name : string;
    thunk : Parsetree.expression;
    optional : bool;
  }

  type event_options_binding = {
    capture : Parsetree.expression option;
    passive : Parsetree.expression option;
    once : Parsetree.expression option;
    prevent_default : Parsetree.expression option;
    stop_propagation : Parsetree.expression option;
  }

  type event_binding = {
    event : string;
    handler : Parsetree.expression;
    options : event_options_binding;
  }

  type class_list_binding = {
    thunk : Parsetree.expression;
  }

  type style_binding = {
    thunk : Parsetree.expression;
  }

  type spread_binding = {
    thunk : Parsetree.expression;
  }

  type ref_binding = {
    handler : Parsetree.expression;
  }

  type bind_kind =
    | Bind_input
    | Bind_checkbox
    | Bind_select
    | Bind_select_multiple

  type bind_binding = {
    kind : bind_kind;
    signal : Parsetree.expression;
    setter : Parsetree.expression;
  }


type static_prop =
  | Static_id of string
  | Static_class of string

   type element_node = {
     loc : Location.t;
     tag : string;
     children : node_part list;
     attrs : attr_binding list;
     events : event_binding list;
     class_list : class_list_binding option;
     style : style_binding option;
     spread : spread_binding option;
     refs : ref_binding list;
     bindings : bind_binding list;
     static_props : static_prop list;
   }


   and node_part =
      | Static_text of string
      | Auto_static_text of string
      | Text_slot of Parsetree.expression
      | Text_once_slot of Parsetree.expression
      | Nodes_slot of Parsetree.expression
     | Nodes_transition_slot of Parsetree.expression
     | Nodes_show_slot of {
         when_ : Parsetree.expression;
         render : Parsetree.expression;
       }
     | Nodes_keyed_slot of {
         items_thunk : Parsetree.expression;
         key_fn : Parsetree.expression;
         render_fn : Parsetree.expression;
       }
    | Nodes_indexed_slot of {
        items_thunk : Parsetree.expression;
        render_fn : Parsetree.expression;
        uses_index : bool;
      }
    | Nodes_indexed_accessors_slot of {
        items_thunk : Parsetree.expression;
        render_fn : Parsetree.expression;
      }
    | Element of element_node


let escape_html (s : string) : string =
  let b = Buffer.create (String.length s) in
  String.iter
    (function
      | '&' -> Buffer.add_string b "&amp;"
      | '<' -> Buffer.add_string b "&lt;"
      | '>' -> Buffer.add_string b "&gt;"
      | '"' -> Buffer.add_string b "&quot;"
      | '\'' -> Buffer.add_string b "&#x27;"
      | c -> Buffer.add_char b c)
    s;
  Buffer.contents b

let is_html_text_longident ~(allow_unqualified_text : bool) (longident : Longident.t) : bool =
  match List.rev (longident_to_list longident) with
  | "text" :: "Html" :: _ -> true
  | [ "text" ] -> allow_unqualified_text
  | _ -> false

let is_whitespace_char = function
  | ' ' | '\n' | '\r' | '\t' -> true
  | _ -> false

let is_formatting_whitespace (s : string) : bool =
  (* Heuristic: ignore whitespace-only nodes that contain a newline/tab.
     This matches how MLX introduces formatting nodes between children.

     Note: we will only apply this heuristic for tags where whitespace is not
     semantically meaningful (i.e. not <pre>/<code>). *)
  let has_linebreak =
    String.exists (function
      | '\n' | '\r' | '\t' -> true
      | _ -> false)
      s
  in
  has_linebreak && String.for_all is_whitespace_char s

let extract_html_text_arg ~(allow_unqualified_text : bool) ~(shadowed_text : bool)
    (expr : Parsetree.expression)
    : Parsetree.expression option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | Some longident ->
        (match List.rev (longident_to_list longident) with
         | [ "text" ] when not allow_unqualified_text ->
           Location.raise_errorf ~loc:expr.pexp_loc
             "solid-ml-template-ppx: unqualified text requires [open Html]. Use Html.text or add open Html.";
         | [ "text" ] when shadowed_text ->
           Location.raise_errorf ~loc:expr.pexp_loc
             "solid-ml-template-ppx: text is shadowed in this module. Use Html.text to avoid ambiguity.";
         | _ -> ());
       if is_html_text_longident ~allow_unqualified_text longident then
         List.find_map
           (function
             | (Asttypes.Nolabel, e) -> Some e
             | _ -> None)
           args
       else None
     | _ -> None)
  | _ -> None

let extract_static_text_literal ~(allow_unqualified_text : bool) ~(shadowed_text : bool)
    (expr : Parsetree.expression)
    : string option =
  match extract_html_text_arg ~allow_unqualified_text ~shadowed_text expr with
  | Some { pexp_desc = Pexp_constant (Pconst_string (s, _, _)); _ } -> Some s
  | _ -> None

let static_attrs_string_of_props (props : static_prop list) : string =
  let static_id =
    List.fold_left
      (fun acc -> function
        | Static_id v -> Some v
        | _ -> acc)
      None props
  in
  let static_class =
    List.fold_left
      (fun acc -> function
        | Static_class v -> Some v
        | _ -> acc)
      None props
  in
  (match static_id with
   | None -> ""
   | Some v -> " id=\"" ^ escape_html v ^ "\"")
  ^
  (match static_class with
   | None -> ""
   | Some v -> " class=\"" ^ escape_html v ^ "\"")

let compile_element_tree ~(loc : Location.t) ~(root : element_node) : Parsetree.expression =
  let open Ast_builder.Default in
  let lid s = { loc; txt = Longident.parse s } in
  let template_var = "__solid_ml_tpl_template" in
  let inst_var = "__solid_ml_tpl_inst" in

  (* Build segments + slots by walking the element tree. *)
  let segments_rev = ref [] in
  let slots_rev :
     (int *
      [ `Text
      | `Text_once
      | `Nodes
      | `Nodes_transition
      | `Nodes_show
      | `Nodes_keyed
      | `Nodes_indexed
      | `Nodes_indexed_i
      | `Nodes_indexed_accessors ]
      * int list * Parsetree.expression)
    list ref =
    ref []
  in
  let element_bindings_rev :
    (int
     * int list
     * attr_binding list
     * event_binding list
     * class_list_binding option
     * style_binding option
     * spread_binding option
     * ref_binding list
     * bind_binding list)
    list
    ref =
    ref [] in
  let select_option_bindings_rev : (bind_kind * Parsetree.expression * int) list ref = ref [] in

  let current_segment = Buffer.create 64 in
  let slot_id = ref 0 in
  let element_id = ref 0 in

  let rec emit_element (path_to_element : int list)
      (active_select_signal : (bind_kind * Parsetree.expression) option)
      (el : element_node) : unit =
    let static_attrs_string = static_attrs_string_of_props el.static_props in
    Buffer.add_string current_segment ("<" ^ el.tag ^ static_attrs_string ^ ">");

    let select_binding =
      List.find_map
        (fun (b : bind_binding) ->
          match b.kind with
          | Bind_select -> Some (Bind_select, b.signal)
          | Bind_select_multiple -> Some (Bind_select_multiple, b.signal)
          | _ -> None)
        el.bindings
    in
    let force_bind =
      match (active_select_signal, el.tag) with
      | (Some _, "option") -> true
      | _ -> false
    in
    let option_has_value =
      List.exists (fun (b : attr_binding) -> String.equal b.name "value") el.attrs
    in
    (match (active_select_signal, el.tag) with
     | (Some _, "option") when not option_has_value ->
       Location.raise_errorf ~loc:el.loc
         "solid-ml-template-ppx: <option> under Tpl.bind_select must include an explicit ~value"
     | _ -> ());
    if el.attrs <> []
       || el.events <> []
       || Option.is_some el.class_list
       || Option.is_some el.style
       || Option.is_some el.spread
       || el.refs <> []
       || el.bindings <> []
       || force_bind
    then (
      let current_id = !element_id in
      element_bindings_rev :=
        ( current_id,
          path_to_element,
          el.attrs,
          el.events,
          el.class_list,
          el.style,
          el.spread,
          el.refs,
          el.bindings )
        :: !element_bindings_rev;
      (match active_select_signal with
       | Some (kind, signal) when String.equal el.tag "option" ->
         select_option_bindings_rev := (kind, signal, current_id) :: !select_option_bindings_rev
       | _ -> ());
      incr element_id);

    let child_index = ref 0 in
    let child_select_signal =
      match (el.tag, select_binding) with
      | ("select", Some binding) -> Some binding
      | ("select", None) -> None
      | _ -> active_select_signal
    in
    List.iter
      (function
        | Static_text s ->
          Buffer.add_string current_segment (escape_html s);
          incr child_index
        | Auto_static_text s ->
          Buffer.add_string current_segment (escape_html s);
          incr child_index
        | Element child_el ->
          emit_element (path_to_element @ [ !child_index ]) child_select_signal child_el;
          incr child_index
        | Text_slot thunk ->
          (* SolidJS-style stable placeholders: we emit a comment marker on both
             sides of every text slot.

             This ensures the slot's text node can be inserted between two
             non-text nodes (comments), so we never accidentally reuse/overwrite
             adjacent static text nodes during CSR/hydration. *)
          Buffer.add_string current_segment "<!--#-->";
          segments_rev := Buffer.contents current_segment :: !segments_rev;
          Buffer.reset current_segment;
          Buffer.add_string current_segment "<!--#-->";
          (* [child_index] is the first marker; the second marker is at
             [child_index+1]. Insert the slot text immediately before the second
             marker. *)
          slots_rev :=
            (!slot_id, `Text, path_to_element @ [ !child_index + 1 ], thunk)
            :: !slots_rev;
          incr slot_id;
          (* Count both markers (the slot text will be inserted at bind time). *)
          child_index := !child_index + 2
        | Text_once_slot thunk ->
          Buffer.add_string current_segment "<!--#-->";
          segments_rev := Buffer.contents current_segment :: !segments_rev;
          Buffer.reset current_segment;
          Buffer.add_string current_segment "<!--#-->";
          slots_rev :=
            (!slot_id, `Text_once, path_to_element @ [ !child_index + 1 ], thunk)
            :: !slots_rev;
          incr slot_id;
          child_index := !child_index + 2
        | Nodes_slot thunk ->
          (* Dynamic child region: paired markers that bracket the region. *)
          Buffer.add_string current_segment "<!--$-->";
          segments_rev := Buffer.contents current_segment :: !segments_rev;
          Buffer.reset current_segment;
          Buffer.add_string current_segment "<!--$-->";
          (* Insert content immediately before the closing marker. *)
          slots_rev :=
            (!slot_id, `Nodes, path_to_element @ [ !child_index + 1 ], thunk)
            :: !slots_rev;
          incr slot_id;
          child_index := !child_index + 2
        | Nodes_show_slot { when_; render } ->
          Buffer.add_string current_segment "<!--$-->";
          segments_rev := Buffer.contents current_segment :: !segments_rev;
          Buffer.reset current_segment;
          Buffer.add_string current_segment "<!--$-->";
          let payload =
            Ast_builder.Default.pexp_tuple ~loc [ when_; render ]
          in
          slots_rev :=
            (!slot_id, `Nodes_show, path_to_element @ [ !child_index + 1 ], payload)
            :: !slots_rev;
          incr slot_id;
          child_index := !child_index + 2
        | Nodes_transition_slot thunk ->
          Buffer.add_string current_segment "<!--$-->";
          segments_rev := Buffer.contents current_segment :: !segments_rev;
          Buffer.reset current_segment;
          Buffer.add_string current_segment "<!--$-->";
          slots_rev :=
            (!slot_id, `Nodes_transition, path_to_element @ [ !child_index + 1 ], thunk)
            :: !slots_rev;
          incr slot_id;
          child_index := !child_index + 2
        | Nodes_keyed_slot { items_thunk; key_fn; render_fn } ->
          Buffer.add_string current_segment "<!--$-->";
          segments_rev := Buffer.contents current_segment :: !segments_rev;
          Buffer.reset current_segment;
          Buffer.add_string current_segment "<!--$-->";
          (* Pack args into a tuple-like thunk expression for later lowering. *)
          let payload =
            Ast_builder.Default.pexp_tuple ~loc [ items_thunk; key_fn; render_fn ]
          in
          slots_rev :=
            (!slot_id, `Nodes_keyed, path_to_element @ [ !child_index + 1 ], payload)
            :: !slots_rev;
          incr slot_id;
          child_index := !child_index + 2
        | Nodes_indexed_slot { items_thunk; render_fn; uses_index } ->
          Buffer.add_string current_segment "<!--$-->";
          segments_rev := Buffer.contents current_segment :: !segments_rev;
          Buffer.reset current_segment;
          Buffer.add_string current_segment "<!--$-->";
          let payload =
            Ast_builder.Default.pexp_tuple ~loc [ items_thunk; render_fn ]
          in
          slots_rev :=
            (!slot_id,
             (if uses_index then `Nodes_indexed_i else `Nodes_indexed),
             path_to_element @ [ !child_index + 1 ],
             payload)
            :: !slots_rev;
          incr slot_id;
          child_index := !child_index + 2
        | Nodes_indexed_accessors_slot { items_thunk; render_fn } ->
          Buffer.add_string current_segment "<!--$-->";
          segments_rev := Buffer.contents current_segment :: !segments_rev;
          Buffer.reset current_segment;
          Buffer.add_string current_segment "<!--$-->";
          let payload =
            Ast_builder.Default.pexp_tuple ~loc [ items_thunk; render_fn ]
          in
          slots_rev :=
            (!slot_id,
             `Nodes_indexed_accessors,
             path_to_element @ [ !child_index + 1 ],
             payload)
            :: !slots_rev;
          incr slot_id;
          child_index := !child_index + 2)
      el.children;

    Buffer.add_string current_segment ("</" ^ el.tag ^ ">")
  in

  emit_element [] None root;
  segments_rev := Buffer.contents current_segment :: !segments_rev;

  let segments = List.rev !segments_rev in
  let slots = List.rev !slots_rev in
  let element_bindings = List.rev !element_bindings_rev in

  let segments_expr = pexp_array ~loc (List.map (estring ~loc) segments) in
  let slot_kinds_expr =
    pexp_array ~loc
      (List.map
           (fun (_id, kind, _path, _thunk) ->
              match kind with
              | `Text
              | `Text_once -> pexp_variant ~loc "Text" None
              | `Nodes -> pexp_variant ~loc "Nodes" None
              | `Nodes_transition -> pexp_variant ~loc "Nodes" None
              | `Nodes_show -> pexp_variant ~loc "Nodes" None
              | `Nodes_keyed -> pexp_variant ~loc "Nodes" None
              | `Nodes_indexed -> pexp_variant ~loc "Nodes" None
              | `Nodes_indexed_i -> pexp_variant ~loc "Nodes" None
              | `Nodes_indexed_accessors -> pexp_variant ~loc "Nodes" None)
           slots)

  in

  let compile_call =
    pexp_apply ~loc
      (pexp_ident ~loc (lid "Html.Internal_template.compile"))
      [ (Labelled "segments", segments_expr);
        (Labelled "slot_kinds", slot_kinds_expr) ]
  in

  let instantiate_call =
    pexp_apply ~loc
      (pexp_ident ~loc (lid "Html.Internal_template.instantiate"))
      [ (Nolabel, evar ~loc template_var) ]
  in

  let root_call =
    pexp_apply ~loc
      (pexp_ident ~loc (lid "Html.Internal_template.root"))
      [ (Nolabel, evar ~loc inst_var) ]
  in

  let path_expr (path : int list) : Parsetree.expression =
    pexp_array ~loc (List.map (eint ~loc) path)
  in

  let attr_effects =
    List.concat_map
      (fun (el_id, _path, (attrs : attr_binding list), _events, _class_list, _style, _spread, _refs, _bindings) ->
        let el_var = "__solid_ml_tpl_el" ^ string_of_int el_id in
        List.map
          (fun ({ name; thunk; optional } : attr_binding) ->
            let thunk_call = pexp_apply ~loc thunk [ (Nolabel, eunit ~loc) ] in
            let value_expr =
              if optional then
                thunk_call
              else
                pexp_construct ~loc (lid "Some") (Some thunk_call)
            in
            let set_attr_call =
              pexp_apply ~loc
                (pexp_ident ~loc (lid "Html.Internal_template.set_attr"))
                [ (Nolabel, evar ~loc el_var);
                  (Labelled "name", estring ~loc name);
                  (Nolabel, value_expr) ]
            in
            pexp_apply ~loc
              (pexp_ident ~loc (lid "Effect.create"))
              [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) set_attr_call) ])
          attrs)
      element_bindings
  in

  let event_effects =
    List.concat_map
      (fun (el_id, _path, _attrs, (events : event_binding list), _class_list, _style, _spread, _refs, _bindings) ->
        let el_var = "__solid_ml_tpl_el" ^ string_of_int el_id in
        List.map
          (fun ({ event; handler; options } : event_binding) ->
            let bool_default = pexp_construct ~loc (lid "false") None in
            let capture_expr = Option.value options.capture ~default:bool_default in
            let passive_expr = Option.value options.passive ~default:bool_default in
            let once_expr = Option.value options.once ~default:bool_default in
            let options_expr =
              if Option.is_none options.capture
                 && Option.is_none options.passive
                 && Option.is_none options.once
              then
                None
              else
                Some
                  (pexp_record ~loc
                     [ (lid "capture", capture_expr);
                       (lid "passive", passive_expr);
                       (lid "once", once_expr) ]
                     None)
            in
            let handler_expr =
              match (options.prevent_default, options.stop_propagation) with
              | (None, None) -> handler
              | _ ->
                let prevent_expr =
                  Option.value options.prevent_default ~default:bool_default
                in
                let stop_expr =
                  Option.value options.stop_propagation ~default:bool_default
                in
                pexp_apply ~loc
                  (pexp_ident ~loc (lid "Html.Internal_template.wrap_handler"))
                  [ (Labelled "prevent_default", prevent_expr);
                    (Labelled "stop_propagation", stop_expr);
                    (Nolabel, handler) ]
            in
            let base_args =
              [ (Nolabel, evar ~loc el_var);
                (Labelled "event", estring ~loc event) ]
            in
            let on_args =
              match options_expr with
              | None -> base_args @ [ (Nolabel, handler_expr) ]
              | Some opts -> base_args @ [ (Labelled "options", opts); (Nolabel, handler_expr) ]
            in
            let off_args =
              match options_expr with
              | None -> base_args @ [ (Nolabel, handler_expr) ]
              | Some opts -> base_args @ [ (Labelled "options", opts); (Nolabel, handler_expr) ]
            in
            let on_call =
              pexp_apply ~loc
                (pexp_ident ~loc (lid "Html.Internal_template.on_"))
                on_args
            in
            let off_call =
              pexp_apply ~loc
                (pexp_ident ~loc (lid "Html.Internal_template.off_"))
                off_args
            in
            let cleanup =
              pexp_apply ~loc (pexp_ident ~loc (lid "Owner.on_cleanup"))
                [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) off_call) ]
            in
            pexp_sequence ~loc on_call cleanup)
          events)
      element_bindings
  in

  let class_list_effects =
    List.filter_map
      (fun (el_id, _path, _attrs, _events, cl_opt, _style, _spread, _refs, _bindings) ->
        match cl_opt with
        | None -> None
        | Some (cl : class_list_binding) ->
          let el_var = "__solid_ml_tpl_el" ^ string_of_int el_id in
          let thunk_call = pexp_apply ~loc cl.thunk [ (Nolabel, eunit ~loc) ] in
          let classes_var = "__solid_ml_tpl_classes" ^ string_of_int el_id in
          let class_str_var = "__solid_ml_tpl_class_str" ^ string_of_int el_id in
          let build_class_str =
            (* Build: String.concat " " (List.map fst (List.filter snd classes)) *)
            let filtered =
              pexp_apply ~loc (pexp_ident ~loc (lid "List.filter"))
                [ (Nolabel,
                   pexp_fun ~loc Nolabel None
                     (ppat_tuple ~loc [ pvar ~loc "_name"; pvar ~loc "enabled" ])
                     (evar ~loc "enabled"));
                  (Nolabel, evar ~loc classes_var) ]
            in
            let mapped =
              pexp_apply ~loc (pexp_ident ~loc (lid "List.map"))
                [ (Nolabel,
                   pexp_fun ~loc Nolabel None
                     (ppat_tuple ~loc [ pvar ~loc "name"; pvar ~loc "_enabled" ])
                     (evar ~loc "name"));
                  (Nolabel, filtered) ]
            in
            pexp_apply ~loc (pexp_ident ~loc (lid "String.concat"))
              [ (Nolabel, estring ~loc " "); (Nolabel, mapped) ]
          in
          let value_expr =
            pexp_ifthenelse ~loc
              (pexp_apply ~loc (pexp_ident ~loc (lid "String.equal"))
                 [ (Nolabel, evar ~loc class_str_var); (Nolabel, estring ~loc "") ])
              (pexp_construct ~loc (lid "None") None)
              (Some (pexp_construct ~loc (lid "Some") (Some (evar ~loc class_str_var))))
          in
          let set_attr_call =
            pexp_apply ~loc (pexp_ident ~loc (lid "Html.Internal_template.set_attr"))
              [ (Nolabel, evar ~loc el_var);
                (Labelled "name", estring ~loc "class");
                (Nolabel, value_expr) ]
          in
          let body =
            pexp_let ~loc Nonrecursive
              [ value_binding ~loc ~pat:(pvar ~loc classes_var) ~expr:thunk_call ]
              (pexp_let ~loc Nonrecursive
                 [ value_binding ~loc ~pat:(pvar ~loc class_str_var) ~expr:build_class_str ]
                 set_attr_call)
          in
          let expr =
            pexp_apply ~loc (pexp_ident ~loc (lid "Effect.create"))
              [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) body) ]
          in
          Some expr)
      element_bindings
  in

  let style_effects =
    List.filter_map
      (fun (el_id, _path, _attrs, _events, _class_list, style_opt, _spread, _refs, _bindings) ->
        match style_opt with
        | None -> None
        | Some (style : style_binding) ->
          let el_var = "__solid_ml_tpl_el" ^ string_of_int el_id in
          let thunk_call = pexp_apply ~loc style.thunk [ (Nolabel, eunit ~loc) ] in
          let styles_var = "__solid_ml_tpl_styles" ^ string_of_int el_id in
          let style_str_var = "__solid_ml_tpl_style_str" ^ string_of_int el_id in
          let filtered =
            pexp_apply ~loc (pexp_ident ~loc (lid "List.filter_map"))
              [ (Nolabel,
                 pexp_fun ~loc Nolabel None
                   (ppat_tuple ~loc [ pvar ~loc "name"; pvar ~loc "value" ])
                   (pexp_match ~loc (evar ~loc "value")
                      [ case ~lhs:(ppat_construct ~loc (lid "Some") (Some (pvar ~loc "v")))
                          ~guard:None
                          ~rhs:
                            (pexp_construct ~loc (lid "Some")
                               (Some
                                  (pexp_apply ~loc
                                     (pexp_ident ~loc (lid "(^)"))
                                     [ (Nolabel, evar ~loc "name");
                                       (Nolabel,
                                        pexp_apply ~loc (pexp_ident ~loc (lid "(^)"))
                                          [ (Nolabel, estring ~loc ":"); (Nolabel, evar ~loc "v") ]) ])));
                        case ~lhs:(ppat_construct ~loc (lid "None") None)
                          ~guard:None
                          ~rhs:(pexp_construct ~loc (lid "None") None) ]));
                (Nolabel, evar ~loc styles_var) ]
          in
          let build_style_str =
            pexp_apply ~loc (pexp_ident ~loc (lid "String.concat"))
              [ (Nolabel, estring ~loc ";"); (Nolabel, filtered) ]
          in
          let value_expr =
            pexp_ifthenelse ~loc
              (pexp_apply ~loc (pexp_ident ~loc (lid "String.equal"))
                 [ (Nolabel, evar ~loc style_str_var); (Nolabel, estring ~loc "") ])
              (pexp_construct ~loc (lid "None") None)
              (Some (pexp_construct ~loc (lid "Some") (Some (evar ~loc style_str_var))))
          in
          let set_attr_call =
            pexp_apply ~loc (pexp_ident ~loc (lid "Html.Internal_template.set_attr"))
              [ (Nolabel, evar ~loc el_var);
                (Labelled "name", estring ~loc "style");
                (Nolabel, value_expr) ]
          in
          let body =
            pexp_let ~loc Nonrecursive
              [ value_binding ~loc ~pat:(pvar ~loc styles_var) ~expr:thunk_call ]
              (pexp_let ~loc Nonrecursive
                 [ value_binding ~loc ~pat:(pvar ~loc style_str_var) ~expr:build_style_str ]
                 set_attr_call)
          in
          let expr =
            pexp_apply ~loc (pexp_ident ~loc (lid "Effect.create"))
              [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) body) ]
          in
          Some expr)
      element_bindings
  in

  let spread_effects =
    List.filter_map
      (fun (el_id, _path, _attrs, _events, _class_list, _style, spread_opt, _refs, _bindings) ->
        match spread_opt with
        | None -> None
        | Some (spread : spread_binding) ->
          let el_var = "__solid_ml_tpl_el" ^ string_of_int el_id in
          let spread_var = "__solid_ml_tpl_spread" ^ string_of_int el_id in
          let spread_state_var = "__solid_ml_tpl_spread_state" ^ string_of_int el_id in
          let thunk_call = pexp_apply ~loc spread.thunk [ (Nolabel, eunit ~loc) ] in
          let apply_call =
            pexp_apply ~loc
              (pexp_ident ~loc (lid "Solid_ml_template_runtime.Spread.apply"))
              [ (Labelled "set_attr", pexp_ident ~loc (lid "Html.Internal_template.set_attr"));
                (Labelled "element", evar ~loc el_var);
                (Nolabel, evar ~loc spread_state_var);
                (Nolabel, evar ~loc spread_var) ]
          in
          let body =
            pexp_let ~loc Nonrecursive
              [ value_binding ~loc ~pat:(pvar ~loc spread_var) ~expr:thunk_call ]
              apply_call
          in
          let effect_expr =
            pexp_apply ~loc (pexp_ident ~loc (lid "Effect.create"))
              [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) body) ]
          in
          let expr =
            pexp_let ~loc Nonrecursive
              [ value_binding ~loc
                  ~pat:(pvar ~loc spread_state_var)
                  ~expr:(pexp_apply ~loc
                           (pexp_ident ~loc (lid "Solid_ml_template_runtime.Spread.create_state"))
                           [ (Nolabel, eunit ~loc) ]) ]
              effect_expr
          in
          Some expr)
      element_bindings
  in

  let ref_effects =
    List.concat_map
      (fun (el_id, _path, _attrs, _events, _class_list, _style, _spread, (refs : ref_binding list), _bindings) ->
        let el_var = "__solid_ml_tpl_el" ^ string_of_int el_id in
        List.map
          (fun (ref_binding : ref_binding) ->
            pexp_apply ~loc ref_binding.handler [ (Nolabel, evar ~loc el_var) ])
          refs)
      element_bindings
  in

  let binding_effects =
    List.concat_map
      (fun (el_id, _path, _attrs, _events, _class_list, _style, _spread, _refs, (bindings : bind_binding list)) ->
        let el_var = "__solid_ml_tpl_el" ^ string_of_int el_id in
        List.concat
          (List.mapi
             (fun idx (binding : bind_binding) ->
        let set_fn, get_fn, event_name =
          match binding.kind with
          | Bind_input -> ("set_value", "get_value", "input")
          | Bind_checkbox -> ("set_checked", "get_checked", "change")
          | Bind_select -> ("set_value", "get_value", "change")
          | Bind_select_multiple -> ("set_selected_values", "get_selected_values", "change")
        in
        let signal_call = pexp_apply ~loc binding.signal [ (Nolabel, eunit ~loc) ] in
        let signal_call =
          match binding.kind with
          | Bind_select_multiple ->
            pexp_apply ~loc (pexp_ident ~loc (lid "Array.of_list"))
              [ (Nolabel, signal_call) ]
          | _ -> signal_call
        in
        let set_call =
          pexp_apply ~loc
            (pexp_ident ~loc (lid ("Html.Internal_template." ^ set_fn)))
            [ (Nolabel, evar ~loc el_var); (Nolabel, signal_call) ]
        in
        let set_call =
          match binding.kind with
          | Bind_select_multiple ->
            let set_multiple =
              pexp_apply ~loc
                (pexp_ident ~loc (lid "Html.Internal_template.set_attr"))
                [ (Nolabel, evar ~loc el_var);
                  (Labelled "name", estring ~loc "multiple");
                  (Nolabel, pexp_construct ~loc (lid "Some") (Some (estring ~loc ""))) ]
            in
            pexp_sequence ~loc set_multiple set_call
          | _ -> set_call
        in
        let set_effect =
          pexp_apply ~loc
            (pexp_ident ~loc (lid "Effect.create"))
            [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) set_call) ]
        in
               let get_call =
                 pexp_apply ~loc
                   (pexp_ident ~loc (lid ("Html.Internal_template." ^ get_fn)))
                   [ (Nolabel, evar ~loc el_var) ]
               in
        let get_call =
          match binding.kind with
          | Bind_select_multiple ->
            pexp_apply ~loc (pexp_ident ~loc (lid "Array.to_list"))
              [ (Nolabel, get_call) ]
          | _ -> get_call
        in
        let setter_call =
          pexp_apply ~loc binding.setter [ (Nolabel, get_call) ]
               in
        let handler_var =
          "__solid_ml_tpl_bind_handler_" ^ string_of_int el_id ^ "_" ^ string_of_int idx
        in
               let handler_expr =
                 pexp_fun ~loc Nolabel None (pvar ~loc "_evt") setter_call
               in
               let on_call =
                 pexp_apply ~loc
                   (pexp_ident ~loc (lid "Html.Internal_template.on_"))
                   [ (Nolabel, evar ~loc el_var);
                     (Labelled "event", estring ~loc event_name);
                     (Nolabel, evar ~loc handler_var) ]
               in
               let off_call =
                 pexp_apply ~loc
                   (pexp_ident ~loc (lid "Html.Internal_template.off_"))
                   [ (Nolabel, evar ~loc el_var);
                     (Labelled "event", estring ~loc event_name);
                     (Nolabel, evar ~loc handler_var) ]
               in
               let cleanup =
                 pexp_apply ~loc (pexp_ident ~loc (lid "Owner.on_cleanup"))
                   [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) off_call) ]
               in
               let event_effect =
                 pexp_let ~loc Nonrecursive
                   [ value_binding ~loc ~pat:(pvar ~loc handler_var) ~expr:handler_expr ]
                   (pexp_sequence ~loc on_call cleanup)
               in
        let observe_effect =
          match binding.kind with
          | Bind_select | Bind_select_multiple ->
            let observe_call =
              pexp_apply ~loc
                (pexp_ident ~loc (lid "Html.Internal_template.observe_children"))
                [ (Nolabel, evar ~loc el_var);
                  (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) set_call) ]
            in
            let observe_var =
              "__solid_ml_tpl_bind_observe_" ^ string_of_int el_id ^ "_" ^ string_of_int idx
            in
            let cleanup_observe =
              pexp_apply ~loc (pexp_ident ~loc (lid "Owner.on_cleanup"))
                [ (Nolabel, evar ~loc observe_var) ]
            in
            let observe_expr =
              pexp_let ~loc Nonrecursive
                [ value_binding ~loc ~pat:(pvar ~loc observe_var) ~expr:observe_call ]
                cleanup_observe
            in
            Some observe_expr
          | _ -> None
        in
        let effects =
          match observe_effect with
          | Some observe_expr -> [ set_effect; event_effect; observe_expr ]
          | None -> [ set_effect; event_effect ]
        in
        effects )
             bindings))
      element_bindings
  in

  let select_option_effects =
    List.map
      (fun (kind, signal, option_id) ->
        let option_var = "__solid_ml_tpl_el" ^ string_of_int option_id in
        let signal_call = pexp_apply ~loc signal [ (Nolabel, eunit ~loc) ] in
        let option_value =
          pexp_apply ~loc
            (pexp_ident ~loc (lid "Html.Internal_template.get_value"))
            [ (Nolabel, evar ~loc option_var) ]
        in
        let selected =
          match kind with
          | Bind_select ->
            pexp_apply ~loc
              (pexp_ident ~loc (lid "String.equal"))
              [ (Nolabel, option_value); (Nolabel, signal_call) ]
          | Bind_select_multiple ->
            pexp_apply ~loc
              (pexp_ident ~loc (lid "List.mem"))
              [ (Nolabel, option_value); (Nolabel, signal_call) ]
          | _ ->
            pexp_construct ~loc (lid "false") None
        in
        let selected_value =
          pexp_ifthenelse ~loc selected
            (pexp_construct ~loc (lid "Some") (Some (estring ~loc "")))
            (Some (pexp_construct ~loc (lid "None") None))
        in
        let set_selected =
          pexp_apply ~loc
            (pexp_ident ~loc (lid "Html.Internal_template.set_attr"))
            [ (Nolabel, evar ~loc option_var);
              (Labelled "name", estring ~loc "selected");
              (Nolabel, selected_value) ]
        in
        pexp_apply ~loc
          (pexp_ident ~loc (lid "Effect.create"))
          [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) set_selected) ])
      (List.rev !select_option_bindings_rev)
  in

  let slot_effects =
     List.map
       (fun (id, kind, _path, thunk) ->
         match kind with
         | `Text ->
           let slot_var = "__solid_ml_tpl_slot" ^ string_of_int id in
           let thunk_call = pexp_apply ~loc thunk [ (Nolabel, eunit ~loc) ] in
           let set_text_call =
             pexp_apply ~loc
               (pexp_ident ~loc (lid "Html.Internal_template.set_text"))
               [ (Nolabel, evar ~loc slot_var); (Nolabel, thunk_call) ]
           in
           pexp_apply ~loc
             (pexp_ident ~loc (lid "Effect.create"))
             [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) set_text_call) ]
         | `Text_once ->
           let slot_var = "__solid_ml_tpl_slot" ^ string_of_int id in
           let thunk_call = pexp_apply ~loc thunk [ (Nolabel, eunit ~loc) ] in
           pexp_apply ~loc
             (pexp_ident ~loc (lid "Html.Internal_template.set_text"))
             [ (Nolabel, evar ~loc slot_var); (Nolabel, thunk_call) ]
        | `Nodes ->
          let slot_var = "__solid_ml_tpl_nodes" ^ string_of_int id in
          let thunk_var = "__solid_ml_tpl_nodes_thunk" ^ string_of_int id in
          (* Ensure subtree effects/listeners are disposed when the region is replaced. *)
          let node_var = "__solid_ml_tpl_nodes_value" ^ string_of_int id in
          let dispose_var = "__solid_ml_tpl_nodes_dispose" ^ string_of_int id in
          let thunk_call = pexp_apply ~loc (evar ~loc thunk_var) [ (Nolabel, eunit ~loc) ] in
          let pair =
            pexp_apply ~loc
              (pexp_ident ~loc (lid "Owner.run_with_root"))
              [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) thunk_call) ]
          in
          let set_nodes_call =
            pexp_apply ~loc
              (pexp_ident ~loc (lid "Html.Internal_template.set_nodes"))
              [ (Nolabel, evar ~loc slot_var); (Nolabel, evar ~loc node_var) ]
          in
          let body =
            pexp_let ~loc Nonrecursive
              [ value_binding ~loc
                  ~pat:(ppat_tuple ~loc [ pvar ~loc node_var; pvar ~loc dispose_var ])
                  ~expr:pair ]
              (pexp_sequence ~loc set_nodes_call (evar ~loc dispose_var))
          in
          pexp_let ~loc Nonrecursive
            [ value_binding ~loc ~pat:(pvar ~loc thunk_var) ~expr:thunk ]
            (pexp_apply ~loc
               (pexp_ident ~loc (lid "Effect.create_with_cleanup"))
               [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) body) ])
        | `Nodes_transition ->
          let slot_var = "__solid_ml_tpl_nodes" ^ string_of_int id in
          let thunk_var = "__solid_ml_tpl_nodes_thunk" ^ string_of_int id in
          let node_var = "__solid_ml_tpl_nodes_value" ^ string_of_int id in
          let dispose_var = "__solid_ml_tpl_nodes_dispose" ^ string_of_int id in
          let thunk_call = pexp_apply ~loc (evar ~loc thunk_var) [ (Nolabel, eunit ~loc) ] in
          let pair =
            pexp_apply ~loc
              (pexp_ident ~loc (lid "Owner.run_with_root"))
              [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) thunk_call) ]
          in
          let set_nodes_call =
            pexp_apply ~loc
              (pexp_ident ~loc (lid "Html.Internal_template.set_nodes"))
              [ (Nolabel, evar ~loc slot_var); (Nolabel, evar ~loc node_var) ]
          in
          let body =
            pexp_let ~loc Nonrecursive
              [ value_binding ~loc
                  ~pat:(ppat_tuple ~loc [ pvar ~loc node_var; pvar ~loc dispose_var ])
                  ~expr:pair ]
              (pexp_sequence ~loc set_nodes_call (evar ~loc dispose_var))
          in
          let effect_call =
            pexp_let ~loc Nonrecursive
              [ value_binding ~loc ~pat:(pvar ~loc thunk_var) ~expr:thunk ]
              (pexp_apply ~loc
                 (pexp_ident ~loc (lid "Effect.create_with_cleanup"))
                 [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) body) ])
          in
          pexp_apply ~loc
            (pexp_ident ~loc (lid "Transition.run"))
            [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) effect_call) ]
        | `Nodes_show ->
          let slot_var = "__solid_ml_tpl_nodes" ^ string_of_int id in
          let when_var = "__solid_ml_tpl_show_when" ^ string_of_int id in
          let render_var = "__solid_ml_tpl_show_render" ^ string_of_int id in
          let prev_var = "__solid_ml_tpl_show_prev" ^ string_of_int id in
          let dispose_var = "__solid_ml_tpl_show_dispose" ^ string_of_int id in
          let visible_var = "__solid_ml_tpl_show_visible" ^ string_of_int id in
          let set_visible_var = "__solid_ml_tpl_show_set_visible" ^ string_of_int id in
          let current_var = "__solid_ml_tpl_show_current" ^ string_of_int id in
          let node_var = "__solid_ml_tpl_show_node" ^ string_of_int id in
          let dispose_node_var = "__solid_ml_tpl_show_dispose_node" ^ string_of_int id in
          let empty_fragment =
            pexp_apply ~loc
              (pexp_ident ~loc (lid "Html.fragment"))
              [ (Nolabel, pexp_construct ~loc (lid "[]") None) ]
          in
          let noop = pexp_fun ~loc Nolabel None (punit ~loc) (eunit ~loc) in
          let when_call = pexp_apply ~loc (evar ~loc when_var) [ (Nolabel, eunit ~loc) ] in
          let render_call = pexp_apply ~loc (evar ~loc render_var) [ (Nolabel, eunit ~loc) ] in
          let render_pair =
            pexp_apply ~loc
              (pexp_ident ~loc (lid "Owner.run_with_root"))
              [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) render_call) ]
          in
          let dispose_get =
            pexp_apply ~loc
              (pexp_ident ~loc (lid "!"))
              [ (Nolabel, evar ~loc dispose_var) ]
          in
          let prev_get =
            pexp_apply ~loc
              (pexp_ident ~loc (lid "!"))
              [ (Nolabel, evar ~loc prev_var) ]
          in
          let set_nodes_call =
            pexp_apply ~loc
              (pexp_ident ~loc (lid "Html.Internal_template.set_nodes"))
              [ (Nolabel, evar ~loc slot_var); (Nolabel, evar ~loc node_var) ]
          in
          let clear_nodes_call =
            pexp_apply ~loc
              (pexp_ident ~loc (lid "Html.Internal_template.set_nodes"))
              [ (Nolabel, evar ~loc slot_var); (Nolabel, empty_fragment) ]
          in
          let set_dispose render_dispose =
            pexp_apply ~loc
              (pexp_ident ~loc (lid ":="))
              [ (Nolabel, evar ~loc dispose_var); (Nolabel, render_dispose) ]
          in
          let set_prev =
            pexp_apply ~loc
              (pexp_ident ~loc (lid ":="))
              [ (Nolabel, evar ~loc prev_var);
                (Nolabel, pexp_construct ~loc (lid "Some") (Some (evar ~loc current_var))) ]
          in
          let mount_body =
            pexp_let ~loc Nonrecursive
              [ value_binding ~loc
                  ~pat:(ppat_tuple ~loc [ pvar ~loc node_var; pvar ~loc dispose_node_var ])
                  ~expr:render_pair ]
              (pexp_sequence ~loc
                 (pexp_apply ~loc dispose_get [ (Nolabel, eunit ~loc) ])
                 (pexp_sequence ~loc set_nodes_call
                    (pexp_sequence ~loc (set_dispose (evar ~loc dispose_node_var)) set_prev)))
          in
          let unmount_body =
            pexp_sequence ~loc
              (pexp_apply ~loc dispose_get [ (Nolabel, eunit ~loc) ])
              (pexp_sequence ~loc clear_nodes_call
                 (pexp_sequence ~loc (set_dispose noop) set_prev))
          in
          let update_body =
            pexp_let ~loc Nonrecursive
              [ value_binding ~loc
                  ~pat:(pvar ~loc current_var)
                  ~expr:(pexp_apply ~loc
                           (pexp_ident ~loc (lid "Signal.get"))
                           [ (Nolabel, evar ~loc visible_var) ]) ]
              (pexp_match ~loc prev_get
                 [ case
                     ~lhs:(ppat_construct ~loc (lid "Some") (Some (ppat_var ~loc { loc; txt = "prev" })))
                     ~guard:(Some (pexp_apply ~loc (pexp_ident ~loc (lid "="))
                                    [ (Nolabel, evar ~loc "prev"); (Nolabel, evar ~loc current_var) ]))
                     ~rhs:(eunit ~loc);
                   case
                     ~lhs:(ppat_any ~loc)
                     ~guard:None
                     ~rhs:(pexp_ifthenelse ~loc (evar ~loc current_var) mount_body (Some unmount_body)) ])
          in
          let sync_effect =
            pexp_apply ~loc
              (pexp_ident ~loc (lid "Effect.create_render_effect"))
              [ (Nolabel,
                 pexp_fun ~loc Nolabel None (punit ~loc)
                   (pexp_let ~loc Nonrecursive
                      [ value_binding ~loc
                          ~pat:(ppat_any ~loc)
                          ~expr:(pexp_apply ~loc
                                   (evar ~loc set_visible_var)
                                   [ (Nolabel, when_call) ]) ]
                      (eunit ~loc))) ]
          in
          let render_effect =
            pexp_apply ~loc
              (pexp_ident ~loc (lid "Effect.create_render_effect"))
              [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) update_body) ]
          in
          let cleanup =
            pexp_apply ~loc
              (pexp_ident ~loc (lid "Owner.on_cleanup"))
              [ (Nolabel,
                 pexp_fun ~loc Nolabel None (punit ~loc)
                   (pexp_apply ~loc dispose_get [ (Nolabel, eunit ~loc) ])) ]
          in
          let bind =
            pexp_let ~loc Nonrecursive
              [ value_binding ~loc
                  ~pat:(ppat_tuple ~loc [ pvar ~loc when_var; pvar ~loc render_var ])
                  ~expr:thunk ]
              (pexp_let ~loc Nonrecursive
                 [ value_binding ~loc
                     ~pat:(ppat_tuple ~loc [ pvar ~loc visible_var; pvar ~loc set_visible_var ])
                     ~expr:(pexp_apply ~loc
                              (pexp_ident ~loc (lid "Signal.create"))
                              [ (Labelled "equals", pexp_ident ~loc (lid "(=)"));
                                (Nolabel, pexp_construct ~loc (lid "false") None) ]);
                   value_binding ~loc
                     ~pat:(pvar ~loc prev_var)
                     ~expr:(pexp_apply ~loc (pexp_ident ~loc (lid "ref"))
                              [ (Nolabel, pexp_construct ~loc (lid "None") None) ]);
                   value_binding ~loc
                     ~pat:(pvar ~loc dispose_var)
                     ~expr:(pexp_apply ~loc (pexp_ident ~loc (lid "ref"))
                              [ (Nolabel, noop) ]) ]
                  (pexp_sequence ~loc sync_effect (pexp_sequence ~loc render_effect cleanup)))
          in
          bind
        | `Nodes_keyed ->
          let slot_var = "__solid_ml_tpl_nodes" ^ string_of_int id in
          let items_var = "__solid_ml_tpl_items" ^ string_of_int id in
          let key_var = "__solid_ml_tpl_key" ^ string_of_int id in
          let render_var = "__solid_ml_tpl_render" ^ string_of_int id in
          (* Slot payload is a tuple: (items_thunk, key_fn, render_fn). *)
          let bind =
            pexp_let ~loc Nonrecursive
              [ value_binding ~loc
                  ~pat:(ppat_tuple ~loc [ pvar ~loc items_var; pvar ~loc key_var; pvar ~loc render_var ])
                  ~expr:thunk ]
              (pexp_apply ~loc
                 (pexp_ident ~loc (lid "Html.Internal_template.set_nodes_keyed"))
                 [ (Nolabel, evar ~loc slot_var);
                   (Labelled "key", evar ~loc key_var);
                   (Labelled "render",
                    pexp_fun ~loc Nolabel None (pvar ~loc "item")
                      (pexp_apply ~loc
                         (pexp_ident ~loc (lid "Owner.run_with_root"))
                         [ (Nolabel,
                            pexp_fun ~loc Nolabel None (punit ~loc)
                              (pexp_apply ~loc (evar ~loc render_var)
                                 [ (Nolabel, evar ~loc "item") ])) ]));
                   (Nolabel, pexp_apply ~loc (evar ~loc items_var) [ (Nolabel, eunit ~loc) ]) ])
          in
          pexp_apply ~loc
            (pexp_ident ~loc (lid "Effect.create"))
            [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) bind) ]
        | `Nodes_indexed ->
          let slot_var = "__solid_ml_tpl_nodes" ^ string_of_int id in
          let items_var = "__solid_ml_tpl_items" ^ string_of_int id in
          let render_var = "__solid_ml_tpl_render" ^ string_of_int id in
          let render_call =
            pexp_apply ~loc (evar ~loc render_var) [ (Nolabel, evar ~loc "item") ]
          in
          let render_body =
            pexp_apply ~loc
              (pexp_ident ~loc (lid "Owner.run_with_root"))
              [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) render_call) ]
          in
          let bind =
            pexp_let ~loc Nonrecursive
              [ value_binding ~loc
                  ~pat:(ppat_tuple ~loc [ pvar ~loc items_var; pvar ~loc render_var ])
                  ~expr:thunk ]
              (pexp_apply ~loc
                 (pexp_ident ~loc (lid "Html.Internal_template.set_nodes_indexed"))
                 [ (Nolabel, evar ~loc slot_var);
                   (Labelled "render",
                    pexp_fun ~loc Nolabel None (pvar ~loc "_idx")
                      (pexp_fun ~loc Nolabel None (pvar ~loc "item") render_body));
                   (Nolabel, pexp_apply ~loc (evar ~loc items_var) [ (Nolabel, eunit ~loc) ]) ])
          in
          pexp_apply ~loc
            (pexp_ident ~loc (lid "Effect.create"))
            [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) bind) ]
        | `Nodes_indexed_i ->
          let slot_var = "__solid_ml_tpl_nodes" ^ string_of_int id in
          let items_var = "__solid_ml_tpl_items" ^ string_of_int id in
          let render_var = "__solid_ml_tpl_render" ^ string_of_int id in
          let render_call =
            pexp_apply ~loc (evar ~loc render_var)
              [ (Nolabel, evar ~loc "idx"); (Nolabel, evar ~loc "item") ]
          in
          let render_body =
            pexp_apply ~loc
              (pexp_ident ~loc (lid "Owner.run_with_root"))
              [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) render_call) ]
          in
          let bind =
            pexp_let ~loc Nonrecursive
              [ value_binding ~loc
                  ~pat:(ppat_tuple ~loc [ pvar ~loc items_var; pvar ~loc render_var ])
                  ~expr:thunk ]
              (pexp_apply ~loc
                 (pexp_ident ~loc (lid "Html.Internal_template.set_nodes_indexed"))
                 [ (Nolabel, evar ~loc slot_var);
                   (Labelled "render",
                    pexp_fun ~loc Nolabel None (pvar ~loc "idx")
                      (pexp_fun ~loc Nolabel None (pvar ~loc "item") render_body));
                   (Nolabel, pexp_apply ~loc (evar ~loc items_var) [ (Nolabel, eunit ~loc) ]) ])
          in
          pexp_apply ~loc
            (pexp_ident ~loc (lid "Effect.create"))
            [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) bind) ]
        | `Nodes_indexed_accessors ->
          let slot_var = "__solid_ml_tpl_nodes" ^ string_of_int id in
          let items_var = "__solid_ml_tpl_items" ^ string_of_int id in
          let render_var = "__solid_ml_tpl_render" ^ string_of_int id in
          pexp_let ~loc Nonrecursive
            [ value_binding ~loc
                ~pat:(ppat_tuple ~loc [ pvar ~loc items_var; pvar ~loc render_var ])
                ~expr:thunk ]
            (pexp_apply ~loc
               (pexp_ident ~loc (lid "Html.Internal_template.set_nodes_indexed_accessors"))
               [ (Nolabel, evar ~loc slot_var);
                 (Labelled "items", evar ~loc items_var);
                 (Labelled "render",
                  pexp_fun ~loc (Labelled "index") None (pvar ~loc "index")
                    (pexp_fun ~loc (Labelled "item") None (pvar ~loc "item")
                       (pexp_apply ~loc
                          (pexp_ident ~loc (lid "Owner.run_with_root"))
                          [ (Nolabel,
                             pexp_fun ~loc Nolabel None (punit ~loc)
                               (pexp_apply ~loc (evar ~loc render_var)
                                  [ (Labelled "index", evar ~loc "index");
                                    (Labelled "item", evar ~loc "item") ])) ]))) ])
      )
      slots
  in

  let effects_in_order =
    attr_effects
    @ event_effects
    @ class_list_effects
    @ style_effects
    @ spread_effects
    @ ref_effects
    @ binding_effects
    @ select_option_effects
    @ slot_effects
  in

  let effects_sequence =
    List.fold_right (fun eff acc -> pexp_sequence ~loc eff acc) effects_in_order
      (eunit ~loc)
  in
  let run_updates_call =
    pexp_apply ~loc
      (pexp_ident ~loc (lid "Html.Internal_template.run_updates"))
      [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) effects_sequence) ]
  in
  let body =
    pexp_sequence ~loc run_updates_call root_call
  in

  (* Bind slots right-to-left to keep insertion indices stable on browser. *)
  let slots_for_binding = List.rev slots in

   let bind_slot acc (id, kind, path, _thunk) =
     match kind with
     | `Text
     | `Text_once ->
      let slot_var = "__solid_ml_tpl_slot" ^ string_of_int id in
      let bind_call =
        pexp_apply ~loc
          (pexp_ident ~loc (lid "Html.Internal_template.bind_text"))
          [ (Nolabel, evar ~loc inst_var);
            (Labelled "id", eint ~loc id);
            (Labelled "path", path_expr path) ]
      in
      pexp_let ~loc Nonrecursive
        [ value_binding ~loc ~pat:(pvar ~loc slot_var) ~expr:bind_call ]
        acc
         | `Nodes
         | `Nodes_transition
         | `Nodes_show
         | `Nodes_keyed
         | `Nodes_indexed
         | `Nodes_indexed_i
         | `Nodes_indexed_accessors ->
      let slot_var = "__solid_ml_tpl_nodes" ^ string_of_int id in
      let bind_call =
        pexp_apply ~loc
          (pexp_ident ~loc (lid "Html.Internal_template.bind_nodes"))
          [ (Nolabel, evar ~loc inst_var);
            (Labelled "id", eint ~loc id);
            (Labelled "path", path_expr path) ]
      in
      pexp_let ~loc Nonrecursive
        [ value_binding ~loc ~pat:(pvar ~loc slot_var) ~expr:bind_call ]
        acc

  in

  let body_with_slots = List.fold_left bind_slot body slots_for_binding in

  let bind_element (el_id, path, _attrs, _events, _class_list, _style, _spread, _refs, _bindings) acc =
    let el_var = "__solid_ml_tpl_el" ^ string_of_int el_id in
    let bind_el_call =
      pexp_apply ~loc
        (pexp_ident ~loc (lid "Html.Internal_template.bind_element"))
        [ (Nolabel, evar ~loc inst_var);
          (Labelled "id", eint ~loc el_id);
          (Labelled "path", path_expr path) ]
    in
    pexp_let ~loc Nonrecursive
      [ value_binding ~loc ~pat:(pvar ~loc el_var) ~expr:bind_el_call ]
      acc
  in

  let body_with_elements =
    List.fold_right bind_element element_bindings body_with_slots
  in

  pexp_let ~loc Nonrecursive
    [ value_binding ~loc ~pat:(pvar ~loc template_var) ~expr:compile_call ]
    (pexp_let ~loc Nonrecursive
       [ value_binding ~loc ~pat:(pvar ~loc inst_var) ~expr:instantiate_call ]
       body_with_elements)


let compile_tag_with_text ~(loc : Location.t) ~(tag : string)
    ~(thunk : Parsetree.expression) : Parsetree.expression =
  compile_element_tree ~loc
    ~root:{
      loc;
      tag;
      children = [ Text_slot thunk ];
      attrs = [];
      events = [];
      class_list = None;
      style = None;
      spread = None;
      refs = [];
      bindings = [];
      static_props = []
    }

let extract_tpl_attr_binding ~(aliases : string list) (expr : Parsetree.expression)
    : attr_binding option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some ("attr" | "attr_opt" as kind) ->
          let optional = String.equal kind "attr_opt" in
          let name_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "name", { pexp_desc = Pexp_constant (Pconst_string (s, _, _)); _ }) ->
                  Some s
                | _ -> None)
              args
          in
          let thunk_opt =
            List.find_map
              (function
                | (Asttypes.Nolabel, thunk) -> Some thunk
                | _ -> None)
              args
          in
          (match (name_opt, thunk_opt) with
           | (Some name, Some thunk) -> Some { name; thunk; optional }
           | _ -> None)
        | _ -> None))
  | _ -> None

let label_to_attr_name (label : string) : string =
  let base =
    let len = String.length label in
    if len > 0 && label.[len - 1] = '_' then String.sub label 0 (len - 1) else label
  in
  String.map (fun c -> if c = '_' then '-' else c) base

let boolean_attr_names =
  [ "disabled";
    "checked";
    "selected";
    "multiple";
    "readonly";
    "required";
    "autofocus";
    "hidden";
    "controls";
    "autoplay";
    "loop";
    "muted";
    "open" ]

let is_boolean_attr_name name = List.exists (String.equal name) boolean_attr_names

let extract_literal_attr_binding ~(aliases : string list) ~(label : string)
    ~(optional : bool) (expr : Parsetree.expression)
    : attr_binding option =
  if optional
     || String.equal label "children"
     || String.equal label "data"
     || String.equal label "attrs"
     || (String.length label >= 2 && String.sub label 0 2 = "on")
     || Option.is_some (tpl_marker_of_expr ~aliases expr)
  then
    None
  else
    match expr.pexp_desc with
    | Pexp_constant (Pconst_string (s, _, _)) ->
      let name = label_to_attr_name label in
      let thunk =
        Ast_builder.Default.pexp_fun ~loc:expr.pexp_loc Nolabel None
          (Ast_builder.Default.punit ~loc:expr.pexp_loc)
          (Ast_builder.Default.estring ~loc:expr.pexp_loc s)
      in
      Some { name; thunk; optional = false }
    | _ -> None

let extract_dynamic_attr_binding ~(aliases : string list) ~(label : string)
    ~(optional : bool) (expr : Parsetree.expression)
    : attr_binding option =
  if String.equal label "children"
     || String.equal label "data"
     || String.equal label "attrs"
     || (String.length label >= 2 && String.sub label 0 2 = "on")
     || Option.is_some (tpl_marker_of_expr ~aliases expr)
  then
    None
  else
    let unit_body_opt : Parsetree.expression option =
      match expr.pexp_desc with
      | Pexp_function (params, _constraint, body) ->
        let is_unit_param =
          match params with
          | [ { pparam_desc = Pparam_val (Asttypes.Nolabel, None, { ppat_desc = Ppat_construct ({ txt = Longident.Lident "()"; _ }, None); _ }); _ } ] -> true
          | [ { pparam_desc = Pparam_val (Asttypes.Nolabel, None, { ppat_desc = Ppat_any; _ }); _ } ] -> true
          | _ -> false
        in
        if not is_unit_param then
          None
        else
          (match body with
           | Pfunction_body body_expr -> Some body_expr
           | Pfunction_cases _ ->
             Location.raise_errorf ~loc:expr.pexp_loc
               "solid-ml-template-ppx: attribute thunks must be simple [fun () -> expr]")
      | _ -> None
    in
    match unit_body_opt with
    | None -> None
    | Some body_expr ->
      let name = label_to_attr_name label in
      let thunk_body, optional =
        if is_boolean_attr_name name then
          let some_empty =
            Ast_builder.Default.pexp_construct ~loc:expr.pexp_loc
              { loc = expr.pexp_loc; txt = Longident.Lident "Some" }
              (Some (Ast_builder.Default.estring ~loc:expr.pexp_loc ""))
          in
          let none =
            Ast_builder.Default.pexp_construct ~loc:expr.pexp_loc
              { loc = expr.pexp_loc; txt = Longident.Lident "None" }
              None
          in
          let conditional =
            Ast_builder.Default.pexp_ifthenelse ~loc:expr.pexp_loc
              body_expr some_empty (Some none)
          in
          (conditional, true)
        else
          (body_expr, optional)
      in
      let thunk =
        Ast_builder.Default.pexp_fun ~loc:expr.pexp_loc Nolabel None
          (Ast_builder.Default.punit ~loc:expr.pexp_loc)
          thunk_body
      in
      Some { name; thunk; optional }

let extract_tpl_text_thunk ~(aliases : string list) (expr : Parsetree.expression)
    : Parsetree.expression option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "text" ->
          List.find_map
            (function
              | (Asttypes.Nolabel, thunk) -> Some thunk
              | _ -> None)
            args
        | Some "text_value" ->
          List.find_map
            (function
              | (Asttypes.Nolabel, value) ->
                Some
                  (Ast_builder.Default.pexp_fun ~loc:value.pexp_loc Nolabel None
                     (Ast_builder.Default.punit ~loc:value.pexp_loc)
                     value)
              | _ -> None)
            args
        | _ -> None))
  | _ -> None

let extract_tpl_nodes_thunk ~(aliases : string list) (expr : Parsetree.expression)
    : Parsetree.expression option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "nodes" ->
          List.find_map
            (function
              | (Asttypes.Nolabel, thunk) -> Some thunk
              | _ -> None)
            args
        | _ -> None))
  | _ -> None

let extract_tpl_show ~(aliases : string list) (expr : Parsetree.expression)
    : (Parsetree.expression * Parsetree.expression) option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some ("show" | "show_when") ->
          let when_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "when_", e) -> Some e
                | _ -> None)
              args
          in
          let render_opt =
            List.find_map
              (function
                | (Asttypes.Nolabel, e) -> Some e
                | _ -> None)
              args
          in
          (match (when_opt, render_opt) with
           | (Some when_, Some render) -> Some (when_, render)
           | _ -> None)
        | _ -> None))
   | _ -> None

let extract_tpl_show_value ~(aliases : string list) (expr : Parsetree.expression)
    : (Parsetree.expression * Parsetree.expression * Parsetree.expression) option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "show_value" ->
          let when_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "when_", e) -> Some e
                | _ -> None)
              args
          in
          let truthy_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "truthy", e) -> Some e
                | _ -> None)
              args
          in
          let render_opt =
            List.find_map
              (function
                | (Asttypes.Nolabel, e) -> Some e
                | _ -> None)
              args
          in
          (match (when_opt, truthy_opt, render_opt) with
           | (Some when_, Some truthy, Some render) -> Some (when_, truthy, render)
           | _ -> None)
        | _ -> None))
  | _ -> None

let extract_tpl_text_once_thunk ~(aliases : string list) (expr : Parsetree.expression)
    : Parsetree.expression option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "text_once" ->
          List.find_map
            (function
              | (Asttypes.Nolabel, thunk) -> Some thunk
              | _ -> None)
            args
        | _ -> None))
  | _ -> None

let extract_tpl_if_ ~(aliases : string list) (expr : Parsetree.expression)
    : (Parsetree.expression * Parsetree.expression * Parsetree.expression) option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "if_" ->
          let when_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "when_", e) -> Some e
                | _ -> None)
              args
          in
          let then_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "then_", e) -> Some e
                | _ -> None)
              args
          in
          let else_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "else_", e) -> Some e
                | _ -> None)
              args
          in
          (match (when_opt, then_opt, else_opt) with
           | (Some when_, Some then_, Some else_) -> Some (when_, then_, else_)
           | _ -> None)
        | _ -> None))
  | _ -> None

let extract_tpl_switch ~(aliases : string list) (expr : Parsetree.expression)
    : (Parsetree.expression * Parsetree.expression) option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "switch" ->
          let match_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "match_", e) -> Some e
                | _ -> None)
              args
          in
          let cases_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "cases", e) -> Some e
                | _ -> None)
              args
          in
          (match (match_opt, cases_opt) with
           | (Some match_, Some cases) -> Some (match_, cases)
           | _ -> None)
        | _ -> None))
  | _ -> None

let extract_tpl_suspense ~(aliases : string list) (expr : Parsetree.expression)
    : (Parsetree.expression * Parsetree.expression) option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "suspense" ->
          let fallback_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "fallback", e) -> Some e
                | _ -> None)
              args
          in
          let render_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "render", e) -> Some e
                | (Asttypes.Nolabel, e) -> Some e
                | _ -> None)
              args
          in
          (match (fallback_opt, render_opt) with
           | (Some fallback, Some render) -> Some (fallback, render)
           | _ -> None)
        | _ -> None))
  | _ -> None

let extract_tpl_error_boundary ~(aliases : string list) (expr : Parsetree.expression)
    : (Parsetree.expression * Parsetree.expression) option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "error_boundary" ->
          let fallback_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "fallback", e) -> Some e
                | _ -> None)
              args
          in
          let render_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "render", e) -> Some e
                | (Asttypes.Nolabel, e) -> Some e
                | _ -> None)
              args
          in
          (match (fallback_opt, render_opt) with
           | (Some fallback, Some render) -> Some (fallback, render)
           | _ -> None)
        | _ -> None))
  | _ -> None

let extract_tpl_dynamic ~(aliases : string list) (expr : Parsetree.expression)
    : (Parsetree.expression * Parsetree.expression) option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "dynamic" ->
          let component_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "component", e) -> Some e
                | _ -> None)
              args
          in
          let props_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "props", e) -> Some e
                | _ -> None)
              args
          in
          (match component_opt with
           | None -> None
           | Some component ->
             let props =
               match props_opt with
               | Some p -> p
               | None ->
                 Ast_builder.Default.pexp_fun ~loc:expr.pexp_loc Nolabel None
                   (Ast_builder.Default.punit ~loc:expr.pexp_loc)
                   (Ast_builder.Default.eunit ~loc:expr.pexp_loc)
             in
             Some (component, props))
        | _ -> None))
  | _ -> None

let extract_tpl_portal ~(aliases : string list) (expr : Parsetree.expression)
    : (Parsetree.expression option * Parsetree.expression option * Parsetree.expression) option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "portal" ->
          let target_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "target", e) -> Some e
                | _ -> None)
              args
          in
          let is_svg_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "is_svg", e) -> Some e
                | _ -> None)
              args
          in
          let render_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "render", e) -> Some e
                | (Asttypes.Nolabel, e) -> Some e
                | _ -> None)
              args
          in
          (match render_opt with
           | Some render -> Some (target_opt, is_svg_opt, render)
           | None -> None)
        | _ -> None))
  | _ -> None

let extract_tpl_suspense_list ~(aliases : string list) (expr : Parsetree.expression)
    : Parsetree.expression option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "suspense_list" ->
          List.find_map
            (function
              | (Asttypes.Labelled "render", e) -> Some e
              | (Asttypes.Nolabel, e) -> Some e
              | _ -> None)
            args
        | _ -> None))
  | _ -> None

let extract_tpl_deferred ~(aliases : string list) (expr : Parsetree.expression)
    : Parsetree.expression option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "deferred" ->
          List.find_map
            (function
              | (Asttypes.Labelled "render", e) -> Some e
              | (Asttypes.Nolabel, e) -> Some e
              | _ -> None)
            args
        | _ -> None))
  | _ -> None

let extract_tpl_transition ~(aliases : string list) (expr : Parsetree.expression)
    : Parsetree.expression option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "transition" ->
          List.find_map
            (function
              | (Asttypes.Labelled "render", e) -> Some e
              | (Asttypes.Nolabel, e) -> Some e
              | _ -> None)
            args
        | _ -> None))
  | _ -> None

let extract_tpl_resource ~(aliases : string list) (expr : Parsetree.expression)
    : (Parsetree.expression * Parsetree.expression * Parsetree.expression * Parsetree.expression) option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "resource" ->
          let resource_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "resource", e) -> Some e
                | _ -> None)
              args
          in
          let loading_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "loading", e) -> Some e
                | _ -> None)
              args
          in
          let error_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "error", e) -> Some e
                | _ -> None)
              args
          in
          let ready_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "ready", e) -> Some e
                | _ -> None)
              args
          in
          (match (resource_opt, loading_opt, error_opt, ready_opt) with
           | (Some resource, Some loading, Some error, Some ready) ->
             Some (resource, loading, error, ready)
           | _ -> None)
        | _ -> None))
  | _ -> None

let extract_tpl_each_keyed ~(aliases : string list) (expr : Parsetree.expression)
    : (Parsetree.expression * Parsetree.expression * Parsetree.expression) option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "each_keyed" ->
          let items_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "items", e) -> Some e
                | _ -> None)
              args
          in
          let key_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "key", e) -> Some e
                | _ -> None)
              args
          in
          let render_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "render", e) -> Some e
                | _ -> None)
              args
          in
          (match (items_opt, key_opt, render_opt) with
           | (Some items, Some key, Some render) -> Some (items, key, render)
           | _ -> None)
        | _ -> None))
   | _ -> None

let extract_tpl_each ~(aliases : string list) (expr : Parsetree.expression)
    : (Parsetree.expression * Parsetree.expression) option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "each" ->
          let items_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "items", e) -> Some e
                | _ -> None)
              args
          in
          let render_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "render", e) -> Some e
                | _ -> None)
              args
          in
          (match (items_opt, render_opt) with
           | (Some items, Some render) -> Some (items, render)
           | _ -> None)
        | _ -> None))
  | _ -> None

let extract_tpl_eachi ~(aliases : string list) (expr : Parsetree.expression)
    : (Parsetree.expression * Parsetree.expression) option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "eachi" ->
          let items_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "items", e) -> Some e
                | _ -> None)
              args
          in
          let render_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "render", e) -> Some e
                | _ -> None)
              args
          in
          (match (items_opt, render_opt) with
           | (Some items, Some render) -> Some (items, render)
           | _ -> None)
        | _ -> None))
  | _ -> None

let extract_tpl_each_indexed ~(aliases : string list) (expr : Parsetree.expression)
    : (Parsetree.expression * Parsetree.expression) option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "each_indexed" ->
          let items_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "items", e) -> Some e
                | _ -> None)
              args
          in
          let render_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "render", e) -> Some e
                | _ -> None)
              args
          in
          (match (items_opt, render_opt) with
           | (Some items, Some render) -> Some (items, render)
           | _ -> None)
        | _ -> None))
  | _ -> None

let extract_tpl_on ~(aliases : string list) (expr : Parsetree.expression) : event_binding option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "on" ->
          let event_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "event", { pexp_desc = Pexp_constant (Pconst_string (s, _, _)); _ }) ->
                  Some s
                | _ -> None)
              args
          in
          let handler_opt =
            List.find_map
              (function
                | (Asttypes.Nolabel, h) -> Some h
                | _ -> None)
              args
          in
          let capture_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "capture", e) -> Some e
                | _ -> None)
              args
          in
          let passive_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "passive", e) -> Some e
                | _ -> None)
              args
          in
          let once_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "once", e) -> Some e
                | _ -> None)
              args
          in
          let prevent_default_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "prevent_default", e) -> Some e
                | _ -> None)
              args
          in
          let stop_propagation_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "stop_propagation", e) -> Some e
                | _ -> None)
              args
          in
          let options =
            { capture = capture_opt;
              passive = passive_opt;
              once = once_opt;
              prevent_default = prevent_default_opt;
              stop_propagation = stop_propagation_opt }
          in
          (match (event_opt, handler_opt) with
           | (Some event, Some handler) -> Some { event; handler; options }
           | _ -> None)
        | _ -> None))
  | _ -> None

let extract_label_on ~(label : string) (expr : Parsetree.expression) : event_binding option =
  let len = String.length label in
  if len <= 2 || not (String.sub label 0 2 = "on") then
    None
  else
    let raw = String.sub label 2 (len - 2) in
    if String.equal raw "" then
      None
    else
      let event =
        raw
        |> String.lowercase_ascii
        |> String.map (fun c -> if c = '_' then '-' else c)
      in
      let options =
        { capture = None;
          passive = None;
          once = None;
          prevent_default = None;
          stop_propagation = None }
      in
      Some { event; handler = expr; options }

let extract_tpl_class_list ~(aliases : string list) (expr : Parsetree.expression) : class_list_binding option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "class_list" ->
          List.find_map
            (function
              | (Asttypes.Nolabel, thunk) -> Some ({ thunk } : class_list_binding)
              | _ -> None)
            args
        | _ -> None))
  | _ -> None

let extract_tpl_style ~(aliases : string list) (expr : Parsetree.expression)
    : style_binding option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "style" ->
          List.find_map
            (function
              | (Asttypes.Nolabel, thunk) -> Some ({ thunk } : style_binding)
              | _ -> None)
            args
        | _ -> None))
  | _ -> None

let extract_tpl_spread ~(aliases : string list) (expr : Parsetree.expression)
    : spread_binding option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "spread" ->
          List.find_map
            (function
              | (Asttypes.Nolabel, thunk) -> Some ({ thunk } : spread_binding)
              | _ -> None)
            args
        | _ -> None))
  | _ -> None

let extract_tpl_ref ~(aliases : string list) (expr : Parsetree.expression)
    : ref_binding option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
        | Some "ref" ->
          List.find_map
            (function
              | (Asttypes.Nolabel, handler) -> Some { handler }
              | _ -> None)
            args
        | _ -> None))
  | _ -> None

let extract_tpl_bind ~(aliases : string list) (expr : Parsetree.expression)
    : bind_binding option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | None -> None
     | Some longident ->
       (match tpl_marker_name ~aliases longident with
         | Some ("bind_input" | "bind_checkbox" | "bind_select" | "bind_select_multiple" as kind) ->
          let signal_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "signal", e) -> Some e
                | _ -> None)
              args
          in
          let setter_opt =
            List.find_map
              (function
                | (Asttypes.Labelled "setter", e) -> Some e
                | _ -> None)
              args
          in
          let positional_args =
            List.filter_map
              (function
                | (Asttypes.Nolabel, e) -> Some e
                | _ -> None)
              args
          in
          let signal_opt =
            match signal_opt with
            | Some _ -> signal_opt
            | None ->
              (match positional_args with
               | signal :: _ -> Some signal
               | _ -> None)
          in
          let setter_opt =
            match setter_opt with
            | Some _ -> setter_opt
            | None ->
              (match positional_args with
               | _signal :: setter :: _ -> Some setter
               | _ -> None)
          in
          let kind =
            match kind with
            | "bind_input" -> Bind_input
            | "bind_checkbox" -> Bind_checkbox
             | "bind_select" -> Bind_select
             | _ -> Bind_select_multiple
          in
          (match (signal_opt, setter_opt) with
           | (Some signal, Some setter) -> Some { kind; signal; setter }
           | _ -> None)
        | _ -> None))
  | _ -> None

let transform_structure (structure : Parsetree.structure) : Parsetree.structure =
  let aliases = collect_tpl_aliases structure in
  let allow_unqualified_text = collect_html_opens structure in
  let shadowed_text = structure_defines_text structure in
  let structure =
    if allow_unqualified_text && (not shadowed_text) && structure_uses_unqualified_text structure then
      add_unused_open_warning_to_html_opens structure
    else structure
  in

  let extract_static_prop = function
    | (Asttypes.Labelled "id", { pexp_desc = Pexp_constant (Pconst_string (s, _, _)); _ }) ->
      Some (Static_id s)
    | (Asttypes.Labelled "class_", { pexp_desc = Pexp_constant (Pconst_string (s, _, _)); _ }) ->
      Some (Static_class s)
    | _ -> None
  in

  let rec compile_expr_force (expr : Parsetree.expression) : Parsetree.expression =
    let mapper =
      object
        inherit Ast_traverse.map as super

        method! expression expr =
          match parse_element_expr
                  ~allow_dynamic_html_text:true
                  ~allow_unqualified_text
                  ~shadowed_text
                  expr
          with
          | Some (root, _dyn) -> compile_element_tree ~loc:expr.pexp_loc ~root
          | None -> super#expression expr
      end
    in
    mapper#expression expr

  and is_likely_node_expression (expr : Parsetree.expression) : bool =
    let has_final_unit_arg args =
      List.exists
        (function
          | (Asttypes.Nolabel, e) -> is_unit_expr e
          | _ -> false)
        args
    in
    let is_known_non_node_function_name = function
      | "string_of_int"
      | "string_of_float"
      | "float_of_int"
      | "int_of_float"
      | "int_of_string"
      | "float_of_string"
      | "fst"
      | "snd"
      | "not"
      | "ignore"
      | "failwith"
      | "invalid_arg"
      | "print_endline"
      | "prerr_endline"
      | "self_init" -> true
      | _ -> false
    in
    match expr.pexp_desc with
    | Pexp_ifthenelse _
    | Pexp_match _
    | Pexp_let _
    | Pexp_sequence _ -> true
    | Pexp_apply (_fn, args) ->
      (* Keep this conservative: only treat function calls as likely node
         expressions when they follow the common OCaml component/helper calling
         style with a final unit argument, e.g. [child ()] or
         [Router.link ~href ... ()].

         This avoids swallowing obviously non-node calls like
         [string_of_int n] into dynamic-node fallback paths. *)
      has_final_unit_arg args
      && (match head_ident expr with
          | Some longident ->
            (match List.rev (longident_to_list longident) with
             | name :: _ -> not (is_known_non_node_function_name name)
             | [] -> true)
          | None -> true)
    | _ -> false

  and child_expr_kind (expr : Parsetree.expression) : string =
    match expr.pexp_desc with
    | Pexp_apply _ -> "function application"
    | Pexp_ifthenelse _ -> "if expression"
    | Pexp_match _ -> "match expression"
    | Pexp_let _ -> "let expression"
    | Pexp_sequence _ -> "sequence expression"
    | Pexp_ident _ -> "identifier"
    | Pexp_constant _ -> "constant"
    | _ -> "expression"

  and compile_expr_force_no_dynamic_text (expr : Parsetree.expression) : Parsetree.expression =
    let mapper =
      object
        inherit Ast_traverse.map as super

         method! expression expr =
          match parse_element_expr
                  ~allow_dynamic_html_text:false
                  ~allow_unqualified_text
                  ~shadowed_text
                  expr
          with
          | Some (root, _dyn) -> compile_element_tree ~loc:expr.pexp_loc ~root
          | None -> super#expression expr
      end
    in
    mapper#expression expr

  and parse_element_expr ~(allow_dynamic_html_text : bool) ~(allow_unqualified_text : bool)
      ~(shadowed_text : bool)
      (expr : Parsetree.expression)
      : (element_node * bool) option =
    match expr.pexp_desc with
    | Pexp_apply (_fn, args) ->
      (match head_ident expr with
       | None -> None
       | Some longident ->
         (match extract_intrinsic_tag longident with
          | None -> None
          | Some tag ->
            let children_arg =
              List.find_map
                (function
                  | (Asttypes.Labelled "children", e) -> Some e
                  | _ -> None)
                args
            in
            let children_arg =
              match children_arg with
              | Some _ -> children_arg
              | None when is_self_closing_intrinsic_tag tag ->
                Some
                  (Ast_builder.Default.pexp_construct ~loc:expr.pexp_loc
                     { loc = expr.pexp_loc; txt = Longident.Lident "[]" }
                     None)
              | None -> None
            in

            let static_props = List.filter_map extract_static_prop args in

              let attr_bindings =
                List.filter_map
                  (function
                    | (Asttypes.Labelled "children", _) -> None
                    | (Asttypes.Nolabel, _e) -> None
                     | (Asttypes.Labelled lbl, e) ->
                       if Option.is_some (extract_static_prop (Asttypes.Labelled lbl, e)) then None
                       else
                         (match extract_tpl_attr_binding ~aliases e with
                          | Some binding -> Some binding
                          | None ->
                            (match extract_literal_attr_binding ~aliases ~label:lbl ~optional:false e with
                             | Some binding -> Some binding
                             | None ->
                               extract_dynamic_attr_binding ~aliases ~label:lbl ~optional:false e))
                     | (Asttypes.Optional lbl, e) ->
                       (match extract_tpl_attr_binding ~aliases e with
                        | Some binding -> Some binding
                        | None ->
                          extract_dynamic_attr_binding ~aliases ~label:lbl ~optional:true e))
                  args
              in

              let event_bindings =
                List.filter_map
                  (function
                    | (Asttypes.Labelled "children", _) -> None
                    | (Asttypes.Nolabel, _e) -> None
                    | (Asttypes.Labelled lbl, e) ->
                      (match extract_label_on ~label:lbl e with
                       | Some binding -> Some binding
                       | None -> extract_tpl_on ~aliases e)
                    | (Asttypes.Optional _lbl, e) -> extract_tpl_on ~aliases e)
                  args
              in

              let class_list_binding =
                List.find_map
                  (function
                    | (Asttypes.Labelled "children", _) -> None
                    | (Asttypes.Nolabel, _e) -> None
                    | (_lbl, e) -> extract_tpl_class_list ~aliases e)
                  args
              in

              let style_binding =
                List.find_map
                  (function
                    | (Asttypes.Labelled "children", _) -> None
                    | (Asttypes.Nolabel, _e) -> None
                    | (_lbl, e) -> extract_tpl_style ~aliases e)
                  args
              in

              let spread_binding =
                List.find_map
                  (function
                    | (Asttypes.Labelled "children", _) -> None
                    | (Asttypes.Nolabel, _e) -> None
                    | (_lbl, e) -> extract_tpl_spread ~aliases e)
                  args
              in

              let ref_bindings =
                List.filter_map
                  (function
                    | (Asttypes.Labelled "children", _) -> None
                    | (Asttypes.Nolabel, _e) -> None
                    | (_lbl, e) -> extract_tpl_ref ~aliases e)
                  args
              in

              let bindings =
                List.filter_map
                  (function
                    | (Asttypes.Labelled "children", _) -> None
                    | (Asttypes.Nolabel, _e) -> None
                    | (_lbl, e) -> extract_tpl_bind ~aliases e)
                  args
              in

            let has_static_id_or_class =
              List.exists
                (function
                  | Static_id _ | Static_class _ -> true)
                static_props
            in
            let has_dynamic_id_or_class =
              List.exists
                (fun (b : attr_binding) ->
                  String.equal b.name "id" || String.equal b.name "class")
                attr_bindings
            in
            if has_static_id_or_class && has_dynamic_id_or_class then
              Location.raise_errorf ~loc:expr.pexp_loc
                "solid-ml-template-ppx: cannot combine static ~id/~class_ with dynamic Tpl.attr(_opt) for id/class";

            let other_args_ok =
              List.for_all
                (function
                  | (Asttypes.Labelled "children", _) -> true
                  | (Asttypes.Nolabel, e) -> is_unit_expr e
                  | (Asttypes.Labelled lbl, e) ->
                    Option.is_some (extract_static_prop (Asttypes.Labelled lbl, e))
                    || Option.is_some (extract_tpl_attr_binding ~aliases e)
                    || Option.is_some (extract_literal_attr_binding ~aliases ~label:lbl ~optional:false e)
                    || Option.is_some
                         (extract_dynamic_attr_binding ~aliases ~label:lbl ~optional:false e)
                    || Option.is_some (extract_label_on ~label:lbl e)
                    || Option.is_some (extract_tpl_on ~aliases e)
                    || Option.is_some (extract_tpl_class_list ~aliases e)
                    || Option.is_some (extract_tpl_style ~aliases e)
                    || Option.is_some (extract_tpl_spread ~aliases e)
                    || Option.is_some (extract_tpl_ref ~aliases e)
                    || Option.is_some (extract_tpl_bind ~aliases e)
                  | (Asttypes.Optional lbl, e) ->
                    Option.is_some (extract_static_prop (Asttypes.Optional lbl, e))
                    || Option.is_some (extract_tpl_attr_binding ~aliases e)
                    || Option.is_some
                         (extract_dynamic_attr_binding ~aliases ~label:lbl ~optional:true e)
                    || Option.is_some (extract_tpl_on ~aliases e)
                    || Option.is_some (extract_tpl_class_list ~aliases e)
                    || Option.is_some (extract_tpl_style ~aliases e)
                    || Option.is_some (extract_tpl_spread ~aliases e)
                    || Option.is_some (extract_tpl_ref ~aliases e)
                    || Option.is_some (extract_tpl_bind ~aliases e))
                 args
              in

              match (children_arg, other_args_ok) with
              | (Some children_expr, true) ->
                let allow_whitespace_normalization =
                  match tag with
                  | "pre" | "code" -> false
                  | _ -> true
                in

                let parts_rev = ref [] in
                let has_dynamic =
                  ref
                    (attr_bindings <> []
                    || event_bindings <> []
                    || Option.is_some class_list_binding
                    || Option.is_some style_binding
                    || Option.is_some spread_binding
                    || ref_bindings <> []
                    || bindings <> [])
                in

                let failed_child = ref None in

                let add_child (child : Parsetree.expression) : bool =
                  match extract_static_text_literal ~allow_unqualified_text ~shadowed_text child with
                  | Some lit
                    when allow_whitespace_normalization && is_formatting_whitespace lit ->
                    true
                  | Some lit ->
                    parts_rev := Static_text lit :: !parts_rev;
                    true
                  | None ->
                    (match child.pexp_desc with
                     | Pexp_constant (Pconst_string (s, _, _)) ->
                       parts_rev := Auto_static_text s :: !parts_rev;
                       true
                     | Pexp_constant (Pconst_integer (s, None)) ->
                       (match int_of_string_opt s with
                        | Some n ->
                          parts_rev := Auto_static_text (string_of_int n) :: !parts_rev;
                          true
                        | None ->
                          failed_child := Some child;
                          false)
                     | Pexp_constant (Pconst_float (s, None)) ->
                       (match float_of_string_opt s with
                        | Some f ->
                          parts_rev := Auto_static_text (string_of_float f) :: !parts_rev;
                          true
                        | None ->
                          failed_child := Some child;
                          false)
                     | Pexp_construct ({ txt = Longident.Lident "true"; _ }, None) ->
                       parts_rev := Auto_static_text "true" :: !parts_rev;
                       true
                     | Pexp_construct ({ txt = Longident.Lident "false"; _ }, None) ->
                       parts_rev := Auto_static_text "false" :: !parts_rev;
                       true
                     | _ ->
                     match extract_tpl_text_thunk ~aliases child with
                     | Some thunk ->
                       has_dynamic := true;
                       parts_rev := Text_slot thunk :: !parts_rev;
                       true
                    | None ->
                      match extract_tpl_text_once_thunk ~aliases child with
                      | Some thunk ->
                        has_dynamic := true;
                        parts_rev := Text_once_slot thunk :: !parts_rev;
                        true
                      | None ->
                        match extract_html_text_arg ~allow_unqualified_text ~shadowed_text child with
                        | Some arg
                          when allow_dynamic_html_text
                               && not (Option.is_some
                                        (extract_static_text_literal
                                           ~allow_unqualified_text
                                           ~shadowed_text
                                           child)) ->
                          has_dynamic := true;
                          parts_rev :=
                            Text_slot
                              (Ast_builder.Default.pexp_fun ~loc:child.pexp_loc Nolabel None
                                 (Ast_builder.Default.punit ~loc:child.pexp_loc)
                                 arg)
                            :: !parts_rev;
                          true
                        | Some arg
                          when not (Option.is_some
                                      (extract_static_text_literal
                                         ~allow_unqualified_text
                                         ~shadowed_text
                                         child)) ->
                          has_dynamic := true;
                          parts_rev :=
                            Text_once_slot
                              (Ast_builder.Default.pexp_fun ~loc:child.pexp_loc Nolabel None
                                 (Ast_builder.Default.punit ~loc:child.pexp_loc)
                                 arg)
                            :: !parts_rev;
                          true
                        | _ ->
                         match extract_tpl_dynamic ~aliases child with
                         | Some (component, props) ->
                           has_dynamic := true;
                           let child_loc = child.pexp_loc in
                           let component_call =
                             Ast_builder.Default.pexp_apply ~loc:child_loc component
                               [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ]
                           in
                           let props_call =
                             Ast_builder.Default.pexp_apply ~loc:child_loc props
                               [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ]
                           in
                           let call =
                             Ast_builder.Default.pexp_apply ~loc:child_loc component_call
                               [ (Nolabel, props_call) ]
                           in
                           let call = compile_expr_force call in
                           let thunk =
                             Ast_builder.Default.pexp_fun ~loc:child_loc Nolabel None
                               (Ast_builder.Default.punit ~loc:child_loc)
                               call
                           in
                           parts_rev := Nodes_transition_slot thunk :: !parts_rev;
                           true
                         | None ->
                        match extract_tpl_portal ~aliases child with
                        | Some (target_opt, is_svg_opt, render) ->
                          has_dynamic := true;
                          let child_loc = child.pexp_loc in
                          let render_call =
                            Ast_builder.Default.pexp_apply ~loc:child_loc render
                              [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ]
                          in
                          let render_call = compile_expr_force render_call in
                          let render_call =
                            Ast_builder.Default.pexp_apply ~loc:child_loc
                              (Ast_builder.Default.pexp_ident ~loc:child_loc
                                 { loc = child_loc; txt = Longident.parse "Effect.untrack" })
                              [ (Nolabel,
                                 Ast_builder.Default.pexp_fun ~loc:child_loc Nolabel None
                                   (Ast_builder.Default.punit ~loc:child_loc)
                                   render_call) ]
                          in
                          let portal_call =
                            let base =
                              Ast_builder.Default.pexp_apply ~loc:child_loc
                                (Ast_builder.Default.pexp_ident ~loc:child_loc
                                   { loc = child_loc; txt = Longident.parse "Html.portal" })
                                [ (Labelled "children", render_call) ]
                            in
                            let with_target =
                              match target_opt with
                              | None -> base
                              | Some target ->
                                Ast_builder.Default.pexp_apply ~loc:child_loc base
                                  [ (Labelled "target", target) ]
                            in
                            match is_svg_opt with
                            | None ->
                              Ast_builder.Default.pexp_apply ~loc:child_loc with_target
                                [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ]
                            | Some is_svg ->
                              let with_svg =
                                Ast_builder.Default.pexp_apply ~loc:child_loc with_target
                                  [ (Labelled "is_svg", is_svg) ]
                              in
                              Ast_builder.Default.pexp_apply ~loc:child_loc with_svg
                                [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ]
                          in
                          let thunk =
                            Ast_builder.Default.pexp_fun ~loc:child_loc Nolabel None
                              (Ast_builder.Default.punit ~loc:child_loc)
                              portal_call
                          in
                          parts_rev := Nodes_transition_slot thunk :: !parts_rev;
                          true
                        | None ->
                        match extract_tpl_suspense_list ~aliases child with
                        | Some render ->
                          has_dynamic := true;
                          let child_loc = child.pexp_loc in
                          let render_call =
                            Ast_builder.Default.pexp_apply ~loc:child_loc render
                              [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ]
                          in
                          let render_call = compile_expr_force render_call in
                          let thunk =
                            Ast_builder.Default.pexp_fun ~loc:child_loc Nolabel None
                              (Ast_builder.Default.punit ~loc:child_loc)
                              render_call
                          in
                          parts_rev := Nodes_slot thunk :: !parts_rev;
                          true
                        | None ->
                        match extract_tpl_deferred ~aliases child with
                        | Some render ->
                          has_dynamic := true;
                          let child_loc = child.pexp_loc in
                          let render_call =
                            Ast_builder.Default.pexp_apply ~loc:child_loc render
                              [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ]
                          in
                          let render_call = compile_expr_force render_call in
                          let thunk =
                            Ast_builder.Default.pexp_fun ~loc:child_loc Nolabel None
                              (Ast_builder.Default.punit ~loc:child_loc)
                              render_call
                          in
                          parts_rev := Nodes_transition_slot thunk :: !parts_rev;
                          true
                        | None ->
                        match extract_tpl_transition ~aliases child with
                        | Some render ->
                          has_dynamic := true;
                          let child_loc = child.pexp_loc in
                          let render_call =
                            Ast_builder.Default.pexp_apply ~loc:child_loc render
                              [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ]
                          in
                          let render_call = compile_expr_force render_call in
                          let thunk =
                            Ast_builder.Default.pexp_fun ~loc:child_loc Nolabel None
                              (Ast_builder.Default.punit ~loc:child_loc)
                              render_call
                          in
                          parts_rev := Nodes_transition_slot thunk :: !parts_rev;
                          true
                        | None ->
                        match extract_tpl_resource ~aliases child with
                        | Some (resource, loading, error, ready) ->
                          has_dynamic := true;
                          let child_loc = child.pexp_loc in
                          let loading_call = compile_expr_force loading in
                          let error_call = compile_expr_force error in
                          let ready_call = compile_expr_force ready in
                          let resource_call =
                            Ast_builder.Default.pexp_apply ~loc:child_loc
                              (Ast_builder.Default.pexp_ident ~loc:child_loc
                                 { loc = child_loc; txt = Longident.parse "Resource.render" })
                              [ (Labelled "loading", loading_call);
                                (Labelled "error", error_call);
                                (Labelled "ready", ready_call);
                                (Nolabel, resource) ]
                          in
                          let thunk =
                            Ast_builder.Default.pexp_fun ~loc:child_loc Nolabel None
                              (Ast_builder.Default.punit ~loc:child_loc)
                              resource_call
                          in
                          parts_rev := Nodes_slot thunk :: !parts_rev;
                          true
                        | None ->
                        match extract_tpl_show ~aliases child with
                        | Some (when_, render) ->
                          has_dynamic := true;
                          let child_loc = child.pexp_loc in
                          let render_call =
                            Ast_builder.Default.pexp_apply ~loc:child_loc render
                              [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ]
                          in
                          let render_call = compile_expr_force render_call in
                          let render_thunk =
                            Ast_builder.Default.pexp_fun ~loc:child_loc Nolabel None
                              (Ast_builder.Default.punit ~loc:child_loc)
                              render_call
                          in
                          parts_rev := Nodes_show_slot { when_; render = render_thunk } :: !parts_rev;
                          true
                            | None ->
                              match extract_tpl_suspense ~aliases child with
                              | Some (fallback, render) ->
                                has_dynamic := true;
                                let child_loc = child.pexp_loc in
                                let fallback = compile_expr_force fallback in
                                let render = compile_expr_force render in
                                let boundary_call =
                                  Ast_builder.Default.pexp_apply ~loc:child_loc
                                    (Ast_builder.Default.pexp_ident ~loc:child_loc
                                       { loc = child_loc; txt = Longident.parse "Suspense.boundary" })
                                    [ (Labelled "fallback", fallback); (Nolabel, render) ]
                                in
                                let boundary_owner =
                                  Ast_builder.Default.pexp_apply ~loc:child_loc
                                    (Ast_builder.Default.pexp_ident ~loc:child_loc
                                       { loc = child_loc; txt = Longident.parse "Owner.run_with_root" })
                                    [ (Nolabel,
                                       Ast_builder.Default.pexp_fun ~loc:child_loc Nolabel None
                                         (Ast_builder.Default.punit ~loc:child_loc)
                                         boundary_call) ]
                                in
                                let node_var = "__solid_ml_tpl_suspense_node" in
                                let dispose_var = "__solid_ml_tpl_suspense_dispose" in
                                let cleanup =
                                  Ast_builder.Default.pexp_apply ~loc:child_loc
                                    (Ast_builder.Default.pexp_ident ~loc:child_loc
                                       { loc = child_loc; txt = Longident.parse "Owner.on_cleanup" })
                                    [ (Nolabel,
                                       Ast_builder.Default.pexp_fun ~loc:child_loc Nolabel None
                                         (Ast_builder.Default.punit ~loc:child_loc)
                                         (Ast_builder.Default.pexp_apply ~loc:child_loc
                                            (Ast_builder.Default.evar ~loc:child_loc dispose_var)
                                            [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ])) ]
                                in
                                let boundary_body =
                                  Ast_builder.Default.pexp_let ~loc:child_loc Nonrecursive
                                    [ Ast_builder.Default.value_binding ~loc:child_loc
                                        ~pat:(Ast_builder.Default.ppat_tuple ~loc:child_loc
                                               [ Ast_builder.Default.pvar ~loc:child_loc node_var;
                                                 Ast_builder.Default.pvar ~loc:child_loc dispose_var ])
                                        ~expr:boundary_owner ]
                                    (Ast_builder.Default.pexp_sequence ~loc:child_loc cleanup
                                       (Ast_builder.Default.evar ~loc:child_loc node_var))
                                in
                                let thunk =
                                  Ast_builder.Default.pexp_fun ~loc:child_loc Nolabel None
                                    (Ast_builder.Default.punit ~loc:child_loc)
                                    boundary_body
                                in
                                parts_rev := Nodes_slot thunk :: !parts_rev;
                                true
                              | None ->
                                match extract_tpl_error_boundary ~aliases child with
                                | Some (fallback, render) ->
                                  has_dynamic := true;
                                  let child_loc = child.pexp_loc in
                                  let fallback = compile_expr_force fallback in
                                  let render = compile_expr_force render in
                                  let boundary_call =
                                    Ast_builder.Default.pexp_apply ~loc:child_loc
                                      (Ast_builder.Default.pexp_ident ~loc:child_loc
                                         { loc = child_loc; txt = Longident.parse "ErrorBoundary.make" })
                                      [ (Labelled "fallback", fallback); (Nolabel, render) ]
                                  in
                                  let boundary_owner =
                                    Ast_builder.Default.pexp_apply ~loc:child_loc
                                      (Ast_builder.Default.pexp_ident ~loc:child_loc
                                         { loc = child_loc; txt = Longident.parse "Owner.run_with_root" })
                                      [ (Nolabel,
                                         Ast_builder.Default.pexp_fun ~loc:child_loc Nolabel None
                                           (Ast_builder.Default.punit ~loc:child_loc)
                                           boundary_call) ]
                                  in
                                  let node_var = "__solid_ml_tpl_error_node" in
                                  let dispose_var = "__solid_ml_tpl_error_dispose" in
                                  let cleanup =
                                    Ast_builder.Default.pexp_apply ~loc:child_loc
                                      (Ast_builder.Default.pexp_ident ~loc:child_loc
                                         { loc = child_loc; txt = Longident.parse "Owner.on_cleanup" })
                                      [ (Nolabel,
                                         Ast_builder.Default.pexp_fun ~loc:child_loc Nolabel None
                                           (Ast_builder.Default.punit ~loc:child_loc)
                                           (Ast_builder.Default.pexp_apply ~loc:child_loc
                                              (Ast_builder.Default.evar ~loc:child_loc dispose_var)
                                              [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ])) ]
                                  in
                                  let boundary_body =
                                    Ast_builder.Default.pexp_let ~loc:child_loc Nonrecursive
                                      [ Ast_builder.Default.value_binding ~loc:child_loc
                                          ~pat:(Ast_builder.Default.ppat_tuple ~loc:child_loc
                                                 [ Ast_builder.Default.pvar ~loc:child_loc node_var;
                                                   Ast_builder.Default.pvar ~loc:child_loc dispose_var ])
                                          ~expr:boundary_owner ]
                                      (Ast_builder.Default.pexp_sequence ~loc:child_loc cleanup
                                         (Ast_builder.Default.evar ~loc:child_loc node_var))
                                  in
                                  let thunk =
                                    Ast_builder.Default.pexp_fun ~loc:child_loc Nolabel None
                                      (Ast_builder.Default.punit ~loc:child_loc)
                                      boundary_body
                                  in
                          parts_rev := Nodes_slot thunk :: !parts_rev;
                          true
                        | None ->
                        match extract_tpl_show_value ~aliases child with
                        | Some (when_, truthy, render) ->
                          has_dynamic := true;
                          let child_loc = child.pexp_loc in
                          let when_call =
                            Ast_builder.Default.pexp_apply ~loc:child_loc when_
                              [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ]
                          in
                          let truthy_call =
                            Ast_builder.Default.pexp_apply ~loc:child_loc truthy
                              [ (Nolabel, when_call) ]
                          in
                          let render_call =
                            Ast_builder.Default.pexp_apply ~loc:child_loc render
                              [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ]
                          in
                          let render_call = compile_expr_force render_call in
                          let empty_fragment =
                            Ast_builder.Default.pexp_apply ~loc:child_loc
                              (Ast_builder.Default.pexp_ident ~loc:child_loc
                                 { loc = child_loc; txt = Longident.parse "Html.fragment" })
                              [ ( Nolabel,
                                  Ast_builder.Default.pexp_construct ~loc:child_loc
                                    { loc = child_loc; txt = Longident.Lident "[]" }
                                    None
                                ) ]
                          in
                          let thunk =
                            Ast_builder.Default.pexp_fun ~loc:child_loc Nolabel None
                              (Ast_builder.Default.punit ~loc:child_loc)
                              (Ast_builder.Default.pexp_ifthenelse ~loc:child_loc truthy_call
                                 render_call
                                 (Some empty_fragment))
                          in
                          parts_rev := Nodes_slot thunk :: !parts_rev;
                          true
                        | None ->
                        match extract_tpl_if_ ~aliases child with
                        | Some (when_, then_, else_) ->
                            has_dynamic := true;
                            let child_loc = child.pexp_loc in
                            let when_call =
                              Ast_builder.Default.pexp_apply ~loc:child_loc when_
                                [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ]
                            in
                            let then_call =
                              Ast_builder.Default.pexp_apply ~loc:child_loc then_
                                [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ]
                            in
                            let else_call =
                              Ast_builder.Default.pexp_apply ~loc:child_loc else_
                                [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ]
                            in
                            let then_call = compile_expr_force then_call in
                            let else_call = compile_expr_force else_call in
                            let thunk =
                              Ast_builder.Default.pexp_fun ~loc:child_loc Nolabel None
                                (Ast_builder.Default.punit ~loc:child_loc)
                                (Ast_builder.Default.pexp_ifthenelse ~loc:child_loc when_call then_call
                                   (Some else_call))
                            in
                            parts_rev := Nodes_slot thunk :: !parts_rev;
                            true
                          | None ->
                            match extract_tpl_switch ~aliases child with
                            | Some (match_, cases) ->
                              has_dynamic := true;
                              let child_loc = child.pexp_loc in
                              let match_call =
                                Ast_builder.Default.pexp_apply ~loc:child_loc match_
                                  [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ]
                              in
                              let cases = compile_expr_force cases in
                              let cases_call =
                                Ast_builder.Default.pexp_apply ~loc:child_loc
                                  (Ast_builder.Default.pexp_ident ~loc:child_loc
                                     { loc = child_loc; txt = Longident.parse "Array.to_list" })
                                  [ (Nolabel, cases) ]
                              in
                              let value_var = "__solid_ml_tpl_switch_value" in
                              let cases_var = "__solid_ml_tpl_switch_cases" in
                              let rendered_var = "__solid_ml_tpl_switch_rendered" in
                              let finder =
                                Ast_builder.Default.pexp_fun ~loc:child_loc Nolabel None
                                  (Ast_builder.Default.ppat_tuple ~loc:child_loc
                                     [ Ast_builder.Default.pvar ~loc:child_loc "pred";
                                       Ast_builder.Default.pvar ~loc:child_loc "render" ])
                                  (Ast_builder.Default.pexp_ifthenelse ~loc:child_loc
                                     (Ast_builder.Default.pexp_apply ~loc:child_loc
                                        (Ast_builder.Default.evar ~loc:child_loc "pred")
                                        [ (Nolabel, Ast_builder.Default.evar ~loc:child_loc value_var) ])
                                     (Ast_builder.Default.pexp_construct ~loc:child_loc
                                        { loc = child_loc; txt = Longident.Lident "Some" }
                                        (Some
                                           (Ast_builder.Default.pexp_apply ~loc:child_loc
                                              (Ast_builder.Default.evar ~loc:child_loc "render")
                                              [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ])))
                                     (Some
                                        (Ast_builder.Default.pexp_construct ~loc:child_loc
                                           { loc = child_loc; txt = Longident.Lident "None" }
                                           None)))
                              in
                              let find_call =
                                Ast_builder.Default.pexp_apply ~loc:child_loc
                                  (Ast_builder.Default.pexp_ident ~loc:child_loc
                                     { loc = child_loc; txt = Longident.parse "List.find_map" })
                                  [ (Nolabel, finder); (Nolabel, Ast_builder.Default.evar ~loc:child_loc cases_var) ]
                              in
                              let empty_fragment =
                                Ast_builder.Default.pexp_apply ~loc:child_loc
                                  (Ast_builder.Default.pexp_ident ~loc:child_loc
                                     { loc = child_loc; txt = Longident.parse "Html.fragment" })
                                  [ ( Nolabel,
                                      Ast_builder.Default.pexp_construct ~loc:child_loc
                                        { loc = child_loc; txt = Longident.Lident "[]" }
                                        None
                                    ) ]
                              in
                              let rendered_match =
                                Ast_builder.Default.pexp_match ~loc:child_loc
                                  (Ast_builder.Default.evar ~loc:child_loc rendered_var)
                                  [ Ast_builder.Default.case
                                      ~lhs:(Ast_builder.Default.ppat_construct ~loc:child_loc
                                             { loc = child_loc; txt = Longident.Lident "Some" }
                                             (Some (Ast_builder.Default.pvar ~loc:child_loc "node")))
                                      ~guard:None
                                      ~rhs:(Ast_builder.Default.evar ~loc:child_loc "node");
                                    Ast_builder.Default.case
                                      ~lhs:(Ast_builder.Default.ppat_construct ~loc:child_loc
                                             { loc = child_loc; txt = Longident.Lident "None" }
                                             None)
                                      ~guard:None
                                      ~rhs:empty_fragment
                                  ]
                              in
                              let body =
                                Ast_builder.Default.pexp_let ~loc:child_loc Nonrecursive
                                  [ Ast_builder.Default.value_binding ~loc:child_loc
                                      ~pat:(Ast_builder.Default.pvar ~loc:child_loc value_var)
                                      ~expr:match_call ]
                                  (Ast_builder.Default.pexp_let ~loc:child_loc Nonrecursive
                                     [ Ast_builder.Default.value_binding ~loc:child_loc
                                         ~pat:(Ast_builder.Default.pvar ~loc:child_loc cases_var)
                                         ~expr:cases_call ]
                                     (Ast_builder.Default.pexp_let ~loc:child_loc Nonrecursive
                                        [ Ast_builder.Default.value_binding ~loc:child_loc
                                            ~pat:(Ast_builder.Default.pvar ~loc:child_loc rendered_var)
                                            ~expr:find_call ]
                                        rendered_match))
                              in
                              let thunk =
                                Ast_builder.Default.pexp_fun ~loc:child_loc Nolabel None
                                  (Ast_builder.Default.punit ~loc:child_loc)
                                  body
                              in
                              parts_rev := Nodes_slot thunk :: !parts_rev;
                              true
                            | None ->
                              match extract_tpl_each_keyed ~aliases child with
                              | Some (items_thunk, key_fn, render_fn) ->
                                has_dynamic := true;
                                parts_rev :=
                                  Nodes_keyed_slot
                                    { items_thunk; key_fn; render_fn = compile_expr_force render_fn }
                                  :: !parts_rev;
                                true
                              | None ->
                                match extract_tpl_each_indexed ~aliases child with
                                | Some (items_thunk, render_fn) ->
                                  has_dynamic := true;
                                  let render_fn = compile_expr_force render_fn in
                                  parts_rev :=
                                    Nodes_indexed_accessors_slot { items_thunk; render_fn }
                                    :: !parts_rev;
                                  true
                                | None ->
                                  match extract_tpl_each ~aliases child with
                                  | Some (items_thunk, render_fn) ->
                                    has_dynamic := true;
                                    let render_fn = compile_expr_force_no_dynamic_text render_fn in
                                    parts_rev :=
                                      Nodes_indexed_slot
                                        { items_thunk; render_fn; uses_index = false }
                                      :: !parts_rev;
                                    true
                                  | None ->
                                    match extract_tpl_eachi ~aliases child with
                                    | Some (items_thunk, render_fn) ->
                                      has_dynamic := true;
                                      let render_fn = compile_expr_force_no_dynamic_text render_fn in
                                      parts_rev :=
                                        Nodes_indexed_slot
                                          { items_thunk; render_fn; uses_index = true }
                                        :: !parts_rev;
                                      true
                                    | None ->
                                      match extract_tpl_nodes_thunk ~aliases child with
                                      | Some thunk ->
                                        has_dynamic := true;
                                        let thunk = compile_expr_force thunk in
                                        parts_rev := Nodes_slot thunk :: !parts_rev;
                                        true
                                      | None ->
                                        match parse_element_expr
                                                ~allow_dynamic_html_text
                                                ~allow_unqualified_text
                                                ~shadowed_text
                                                child with
                                        | Some (child_el, child_dynamic) ->
                                          if child_dynamic then has_dynamic := true;
                                          parts_rev := Element child_el :: !parts_rev;
                                          true
                                        | None ->
                                          if !has_dynamic && is_likely_node_expression child then (
                                            let thunk_expr = compile_expr_force child in
                                            let thunk =
                                              Ast_builder.Default.pexp_fun ~loc:child.pexp_loc Nolabel None
                                                (Ast_builder.Default.punit ~loc:child.pexp_loc)
                                                thunk_expr
                                            in
                                            parts_rev := Nodes_slot thunk :: !parts_rev;
                                            true
                                          ) else (
                                            failed_child := Some child;
                                            false
                                          ))
                in

                let children_list =
                  match list_of_expr children_expr with
                  | Some children_list -> children_list
                  | None -> [ children_expr ]
                in

                if List.for_all add_child children_list then (
                  let children = List.rev !parts_rev in
                  Some
                      ( { loc = expr.pexp_loc;
                          tag;
                          children;
                          attrs = attr_bindings;
                          events = event_bindings;
                          class_list = class_list_binding;
                          style = style_binding;
                          spread = spread_binding;
                          refs = ref_bindings;
                          bindings;
                          static_props
                        },
                      !has_dynamic )
                )
                else
                  (* Provide helpful error message for failed child, but only for obvious mistakes *)
                  (match !failed_child with
                   | Some failed ->
                     (match failed.pexp_desc with
                      | Pexp_constant (Pconst_string (s, _, _)) ->
                        Location.raise_errorf ~loc:failed.pexp_loc
                          "solid-ml-template-ppx: bare string literals are not supported in JSX.\n\n\
                            \  Found: \"%s\"\n\n\
                            \  Fix: Use (text \"%s\") or Html.text \"%s\" instead.\n\
                            \  Example: <div>(text \"Hello\")</div>" s s s
                      | _ ->
                        if !has_dynamic then
                          Location.raise_errorf ~loc:failed.pexp_loc
                            "solid-ml-template-ppx: unsupported JSX child %s in a dynamic template.\n\n\
                             Wrap dynamic text with Tpl.text/Tpl.text_value, or use Html.text for literals.\n\
                             For node expressions, either use a direct node-producing helper call (for example [child ()])\n\
                             or wrap explicitly with [Tpl.nodes (fun () -> ...)]."
                            (child_expr_kind failed)
                        else
                          (* For other unrecognized children (function calls, etc.), silently skip
                             template processing and leave as regular OCaml code. This is the
                             original behavior. *)
                          None)
                   | None -> None)
              | _ -> None))
    | _ -> None
  in

  let rec has_auto_static_text (root : element_node) : bool =
    List.exists
      (function
        | Auto_static_text _ -> true
        | Element child -> has_auto_static_text child
        | _ -> false)
      root.children
  in

  let mapper =
      object
        inherit Ast_traverse.map as super

        method! expression expr =
         match parse_element_expr
                 ~allow_dynamic_html_text:false
                 ~allow_unqualified_text
                 ~shadowed_text
                 expr
         with
         | Some (root, dynamic) when dynamic || has_auto_static_text root ->
            compile_element_tree ~loc:expr.pexp_loc ~root
          | _ -> super#expression expr
       end
  in

  mapper#structure structure

let impl (structure : Parsetree.structure) : Parsetree.structure =
  let structure = transform_structure structure in
  match contains_tpl_markers structure with
  | None -> structure
  | Some (loc, name) ->
    Location.raise_errorf ~loc
      "solid-ml-template-ppx: found unsupported Tpl.%s.\n\n\
       Current supported subset: %s.\n\n\
       If you intended template lowering here, check setup:\n\
         1) In dune-project, enable the `mlx` dialect for `.mlx` files.\n\
         2) In the dune stanza compiling this file, include:\n\
              (preprocess (pps solid-ml-template-ppx))\n\
       See docs/guide-mlx.md for the canonical setup."
      name supported_subset

let () =
  Driver.register_transformation
    ~impl
    "solid-ml-template-ppx"
