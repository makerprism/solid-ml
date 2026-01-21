open Ppxlib

let known_tpl_markers =
  [ "text";
    "nodes";
    "attr";
    "attr_opt";
    "class_list";
    "on";
    "show";
    "each_keyed"
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
   "<tag> (or Html.<tag>) ~children:[text/Html.text \"<literal>\"; Tpl.text <thunk>; Tpl.text_value <value>; Tpl.show ...; Tpl.each_keyed ...; <tag>/Html.<tag> ...; ...] ()\n\
    - supports nested intrinsic tags in children\n\
    - emits `<!--#-->` comment markers before text slots (SolidJS-style) to stabilize DOM paths\n\
    - emits `<!--$-->` markers for dynamic node regions\n\
    - ignores formatting-only whitespace Html.text literals containing newlines/tabs (except under <pre>/<code>)\n\
    - supports static ~id:\"...\" and ~class_:\"...\"\n\
    - supports Tpl.attr/Tpl.attr_opt in labelled args (string literal ~name)\n\
    - supports Tpl.on and Tpl.class_list in labelled args\n\
    - no other props; <tag> in {div,span,p,a,button,ul,li,strong,em,section,main,header,footer,nav,pre,code,h1..h6}"


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
    "div";
    "span";
    "p";
    "a";
    "button";
    "ul";
    "li";
    "strong";
    "em";
    "section";
    "main";
    "header";
    "footer";
    "nav";
    "pre";
    "code";
    "h1";
    "h2";
    "h3";
    "h4";
    "h5";
    "h6";
  ]

let is_supported_intrinsic_tag tag =
  List.exists (String.equal tag) supported_intrinsic_tags

let extract_intrinsic_tag (longident : Longident.t) : string option =
  match List.rev (longident_to_list longident) with
  | tag :: _ when is_supported_intrinsic_tag tag -> Some tag
  | _ -> None

  type attr_binding = {
    name : string;
    thunk : Parsetree.expression;
    optional : bool;
  }

  type event_binding = {
    event : string;
    handler : Parsetree.expression;
  }

  type class_list_binding = {
    thunk : Parsetree.expression;
  }


type static_prop =
  | Static_id of string
  | Static_class of string

  type element_node = {
    tag : string;
    children : node_part list;
    attrs : attr_binding list;
    events : event_binding list;
    class_list : class_list_binding option;
    static_props : static_prop list;
  }


  and node_part =
    | Static_text of string
    | Text_slot of Parsetree.expression
    | Nodes_slot of Parsetree.expression
    | Nodes_keyed_slot of {
        items_thunk : Parsetree.expression;
        key_fn : Parsetree.expression;
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
  let slots_rev : (int * [ `Text | `Nodes | `Nodes_keyed ] * int list * Parsetree.expression) list ref = ref [] in
  let element_bindings_rev :
    (int * int list * attr_binding list * event_binding list * class_list_binding option) list ref =
    ref [] in

  let current_segment = Buffer.create 64 in
  let slot_id = ref 0 in
  let element_id = ref 0 in

  let rec emit_element (path_to_element : int list) (el : element_node) : unit =
    let static_attrs_string = static_attrs_string_of_props el.static_props in
    Buffer.add_string current_segment ("<" ^ el.tag ^ static_attrs_string ^ ">");

    if el.attrs <> [] || el.events <> [] || Option.is_some el.class_list then (
      element_bindings_rev :=
        (!element_id, path_to_element, el.attrs, el.events, el.class_list) :: !element_bindings_rev;
      incr element_id);

    let child_index = ref 0 in
    List.iter
      (function
        | Static_text s ->
          Buffer.add_string current_segment (escape_html s);
          incr child_index
        | Element child_el ->
          emit_element (path_to_element @ [ !child_index ]) child_el;
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
          child_index := !child_index + 2)
      el.children;

    Buffer.add_string current_segment ("</" ^ el.tag ^ ">")
  in

  emit_element [] root;
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
            | `Text -> pexp_variant ~loc "Text" None
            | `Nodes -> pexp_variant ~loc "Nodes" None
            | `Nodes_keyed -> pexp_variant ~loc "Nodes" None)
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
      (fun (el_id, _path, (attrs : attr_binding list), _events, _class_list) ->
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
      (fun (el_id, _path, _attrs, (events : event_binding list), _class_list) ->
        let el_var = "__solid_ml_tpl_el" ^ string_of_int el_id in
        List.map
          (fun ({ event; handler } : event_binding) ->
            let on_call =
              pexp_apply ~loc
                (pexp_ident ~loc (lid "Html.Internal_template.on_"))
                [ (Nolabel, evar ~loc el_var);
                  (Labelled "event", estring ~loc event);
                  (Nolabel, handler) ]
            in
            let off_call =
              pexp_apply ~loc
                (pexp_ident ~loc (lid "Html.Internal_template.off_"))
                [ (Nolabel, evar ~loc el_var);
                  (Labelled "event", estring ~loc event);
                  (Nolabel, handler) ]
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
      (fun (el_id, _path, _attrs, _events, cl_opt) ->
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
        | `Nodes ->
          let slot_var = "__solid_ml_tpl_nodes" ^ string_of_int id in
          (* Ensure subtree effects/listeners are disposed when the region is replaced. *)
          let node_var = "__solid_ml_tpl_nodes_value" ^ string_of_int id in
          let dispose_var = "__solid_ml_tpl_nodes_dispose" ^ string_of_int id in
          let thunk_call = pexp_apply ~loc thunk [ (Nolabel, eunit ~loc) ] in
          let pair =
            pexp_apply ~loc
              (pexp_ident ~loc (lid "Owner.run_with_owner"))
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
          pexp_apply ~loc
            (pexp_ident ~loc (lid "Effect.create_with_cleanup"))
            [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) body) ]
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
                         (pexp_ident ~loc (lid "Owner.run_with_owner"))
                         [ (Nolabel,
                            pexp_fun ~loc Nolabel None (punit ~loc)
                              (pexp_apply ~loc (evar ~loc render_var)
                                 [ (Nolabel, evar ~loc "item") ])) ]));
                   (Nolabel, pexp_apply ~loc (evar ~loc items_var) [ (Nolabel, eunit ~loc) ]) ])
          in
          pexp_apply ~loc
            (pexp_ident ~loc (lid "Effect.create"))
            [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) bind) ] )
      slots
  in

  let effects_in_order = attr_effects @ event_effects @ class_list_effects @ slot_effects in

  let body =
    List.fold_right (fun eff acc -> pexp_sequence ~loc eff acc) effects_in_order
      root_call
  in

  (* Bind slots right-to-left to keep insertion indices stable on browser. *)
  let slots_for_binding = List.rev slots in

  let bind_slot acc (id, kind, path, _thunk) =
    match kind with
    | `Text ->
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
    | `Nodes | `Nodes_keyed ->
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

  let bind_element (el_id, path, _attrs, _events, _class_list) acc =
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
    ~root:{ tag; children = [ Text_slot thunk ]; attrs = []; events = []; class_list = None; static_props = [] }

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
        | Some "show" ->
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
          (match (event_opt, handler_opt) with
           | (Some event, Some handler) -> Some { event; handler }
           | _ -> None)
        | _ -> None))
  | _ -> None

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
              | (Asttypes.Nolabel, thunk) -> Some { thunk }
              | _ -> None)
            args
        | _ -> None))
  | _ -> None

let transform_structure (structure : Parsetree.structure) : Parsetree.structure =
  let aliases = collect_tpl_aliases structure in
  let allow_unqualified_text = collect_html_opens structure in
  let shadowed_text = structure_defines_text structure in

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

            let static_props = List.filter_map extract_static_prop args in

             let attr_bindings =
               List.filter_map
                 (function
                   | (Asttypes.Labelled "children", _) -> None
                   | (Asttypes.Nolabel, _e) -> None
                   | (Asttypes.Labelled _lbl, e)
                   | (Asttypes.Optional _lbl, e) ->
                     extract_tpl_attr_binding ~aliases e)
                 args
             in

             let event_bindings =
               List.filter_map
                 (function
                   | (Asttypes.Labelled "children", _) -> None
                   | (Asttypes.Nolabel, _e) -> None
                   | (_lbl, e) -> extract_tpl_on ~aliases e)
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
                  | arg ->
                    Option.is_some (extract_static_prop arg)
                     || Option.is_some (extract_tpl_attr_binding ~aliases (snd arg))
                     || Option.is_some (extract_tpl_on ~aliases (snd arg))
                     || Option.is_some (extract_tpl_class_list ~aliases (snd arg)))
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
                    || Option.is_some class_list_binding)
                in

                let add_child (child : Parsetree.expression) : bool =
                  match extract_static_text_literal ~allow_unqualified_text ~shadowed_text child with
                  | Some lit
                    when allow_whitespace_normalization && is_formatting_whitespace lit ->
                    true
                  | Some lit ->
                    parts_rev := Static_text lit :: !parts_rev;
                    true
                  | None ->
                     (match extract_tpl_text_thunk ~aliases child with
                      | Some thunk ->
                        has_dynamic := true;
                        parts_rev := Text_slot thunk :: !parts_rev;
                        true
                      | None ->
                          (match extract_html_text_arg ~allow_unqualified_text ~shadowed_text child with
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
                          | _ ->
                            (match extract_tpl_show ~aliases child with
                            | Some (when_, render) ->
                          has_dynamic := true;
                          let child_loc = child.pexp_loc in
                          let when_call =
                            Ast_builder.Default.pexp_apply ~loc:child_loc when_
                              [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ]
                          in
                          let render_call =
                            Ast_builder.Default.pexp_apply ~loc:child_loc render
                              [ (Nolabel, Ast_builder.Default.eunit ~loc:child_loc) ]
                          in
                          let render_call = compile_expr_force render_call in
                          let thunk =
                            Ast_builder.Default.pexp_fun ~loc:child_loc Nolabel None
                              (Ast_builder.Default.punit ~loc:child_loc)
                              (Ast_builder.Default.pexp_ifthenelse ~loc:child_loc when_call render_call
                                 (Some
                                    (Ast_builder.Default.pexp_apply ~loc:child_loc
                                       (Ast_builder.Default.pexp_ident ~loc:child_loc
                                          { loc = child_loc; txt = Longident.parse "Html.fragment" })
                                       [ ( Nolabel,
                                           Ast_builder.Default.pexp_construct ~loc:child_loc
                                             { loc = child_loc; txt = Longident.Lident "[]" }
                                             None
                                         )
                                       ])))
                          in
                          parts_rev := Nodes_slot thunk :: !parts_rev;
                          true
                        | None ->
                          (match extract_tpl_each_keyed ~aliases child with
                           | Some (items_thunk, key_fn, render_fn) ->
                             has_dynamic := true;
                             parts_rev :=
                               Nodes_keyed_slot
                                 { items_thunk; key_fn; render_fn = compile_expr_force render_fn }
                               :: !parts_rev;
                             true
                           | None ->
                             (match extract_tpl_nodes_thunk ~aliases child with
                              | Some thunk ->
                                has_dynamic := true;
                                let thunk = compile_expr_force thunk in
                                parts_rev := Nodes_slot thunk :: !parts_rev;
                                true
                              | None ->
                                 (match parse_element_expr
                                          ~allow_dynamic_html_text
                                          ~allow_unqualified_text
                                          ~shadowed_text
                                          child with
                                  | Some (child_el, child_dynamic) ->
                                   if child_dynamic then has_dynamic := true;
                                   parts_rev := Element child_el :: !parts_rev;
                                   true
                                  | None -> false))))))
                in

                let children_list =
                  match list_of_expr children_expr with
                  | Some children_list -> children_list
                  | None -> [ children_expr ]
                in

                if List.for_all add_child children_list then (
                  let children = List.rev !parts_rev in
                  Some
                    ( { tag;
                        children;
                        attrs = attr_bindings;
                        events = event_bindings;
                        class_list = class_list_binding;
                        static_props
                      },
                      !has_dynamic )
                )
                else
                  None
              | _ -> None))
    | _ -> None
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
        | Some (root, true) ->
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
       If you intended to use the template compiler here, ensure this file is built with:\n\
         (preprocess (pps solid-ml-template-ppx))\n\
       For `.mlx` authoring, enable the `mlx` dialect in your `dune-project` (see MLX README)."
      name supported_subset

let () =
  Driver.register_transformation
    ~impl
    "solid-ml-template-ppx"
