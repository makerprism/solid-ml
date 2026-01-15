open Ppxlib

let known_tpl_markers =
  [ "text"; "attr"; "attr_opt"; "class_list"; "on"; "show"; "each_keyed" ]

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
  "Html.<tag> ~children:[Html.text \"<literal>\"; Tpl.text <thunk>; ...] ()\n\
   - ignores formatting-only whitespace Html.text literals that contain newlines\n\
   - supports static ~id:\"...\" and ~class_:\"...\"\n\
   - supports Tpl.attr/Tpl.attr_opt in labelled args (string literal ~name)\n\
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

type child_part =
  | Static_text of string
  | Text_slot of Parsetree.expression

type attr_binding = {
  name : string;
  thunk : Parsetree.expression;
  optional : bool;
}

type static_prop =
  | Static_id of string
  | Static_class of string

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

let is_html_text_longident (longident : Longident.t) : bool =
  match List.rev (longident_to_list longident) with
  | "text" :: "Html" :: _ -> true
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

let extract_static_text_literal (expr : Parsetree.expression) : string option =
  match expr.pexp_desc with
  | Pexp_apply (_fn, args) ->
    (match head_ident expr with
     | Some longident when is_html_text_longident longident ->
       List.find_map
         (function
           | (Asttypes.Nolabel, { pexp_desc = Pexp_constant (Pconst_string (s, _, _)); _ }) ->
             Some s
           | _ -> None)
         args
     | _ -> None)
  | _ -> None

let compile_tag_with_children ~(loc : Location.t) ~(tag : string)
    ~(children : child_part list) ~(attrs : attr_binding list)
    ~(static_props : static_prop list) : Parsetree.expression =
  let open Ast_builder.Default in
  let lid s = { loc; txt = Longident.parse s } in
  let template_var = "__solid_ml_tpl_template" in
  let inst_var = "__solid_ml_tpl_inst" in
  let el_var = "__solid_ml_tpl_el0" in

  (* Build segments + slots. *)
  let segments_rev = ref [] in
  let slots_rev : (int * int * Parsetree.expression) list ref = ref [] in
  let current_segment = Buffer.create 64 in
  let static_nodes = ref 0 in
  let slot_id = ref 0 in

  let static_id =
    List.fold_left
      (fun acc -> function
        | Static_id v -> Some v
        | _ -> acc)
      None static_props
  in
  let static_class =
    List.fold_left
      (fun acc -> function
        | Static_class v -> Some v
        | _ -> acc)
      None static_props
  in
  let static_attrs_string =
    (match static_id with
     | None -> ""
     | Some v -> " id=\"" ^ escape_html v ^ "\"")
    ^
    (match static_class with
     | None -> ""
     | Some v -> " class=\"" ^ escape_html v ^ "\"")
  in
  Buffer.add_string current_segment ("<" ^ tag ^ static_attrs_string ^ ">");

  List.iter
    (function
      | Static_text s ->
        let escaped = escape_html s in
        Buffer.add_string current_segment escaped;
        incr static_nodes
      | Text_slot thunk ->
        segments_rev := Buffer.contents current_segment :: !segments_rev;
        Buffer.reset current_segment;
        slots_rev := (!slot_id, !static_nodes, thunk) :: !slots_rev;
        incr slot_id)
    children;

  Buffer.add_string current_segment ("</" ^ tag ^ ">");
  segments_rev := Buffer.contents current_segment :: !segments_rev;

  let slots = List.rev !slots_rev in
  let segments = List.rev !segments_rev in

  let segments_expr = pexp_array ~loc (List.map (estring ~loc) segments) in
  let slot_kinds_expr =
    pexp_array ~loc
      (List.map (fun _ -> pexp_variant ~loc "Text" None) slots)
  in

  let compile_call =
    pexp_apply ~loc
      (pexp_ident ~loc (lid "Html.Template.compile"))
      [ (Labelled "segments", segments_expr);
        (Labelled "slot_kinds", slot_kinds_expr) ]
  in

  let instantiate_call =
    pexp_apply ~loc
      (pexp_ident ~loc (lid "Html.Template.instantiate"))
      [ (Nolabel, evar ~loc template_var) ]
  in

  let root_call =
    pexp_apply ~loc
      (pexp_ident ~loc (lid "Html.Template.root"))
      [ (Nolabel, evar ~loc inst_var) ]
  in

  let bind_root_el_call =
    pexp_apply ~loc
      (pexp_ident ~loc (lid "Html.Template.bind_element"))
      [ (Nolabel, evar ~loc inst_var);
        (Labelled "id", eint ~loc 0);
        (Labelled "path", pexp_array ~loc []) ]
  in

  let attr_effects =
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
            (pexp_ident ~loc (lid "Html.Template.set_attr"))
            [ (Nolabel, evar ~loc el_var);
              (Labelled "name", estring ~loc name);
              (Nolabel, value_expr) ]
        in
        pexp_apply ~loc
          (pexp_ident ~loc (lid "Effect.create"))
          [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) set_attr_call) ])
      attrs
  in

  let effects_in_order =
    attr_effects
    @ List.map
        (fun (id, _insert_idx, thunk) ->
          let slot_var = "__solid_ml_tpl_slot" ^ string_of_int id in
          let thunk_call = pexp_apply ~loc thunk [ (Nolabel, eunit ~loc) ] in
          let set_text_call =
            pexp_apply ~loc
              (pexp_ident ~loc (lid "Html.Template.set_text"))
              [ (Nolabel, evar ~loc slot_var); (Nolabel, thunk_call) ]
          in
          pexp_apply ~loc
            (pexp_ident ~loc (lid "Effect.create"))
            [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) set_text_call) ])
        slots
  in

  let body =
    List.fold_right (fun eff acc -> pexp_sequence ~loc eff acc) effects_in_order
      root_call
  in

  (* Bind slots right-to-left to keep insertion indices stable on browser. *)
  let slots_for_binding = List.rev slots in

  let bind_slot acc (id, insert_idx, _thunk) =
    let slot_var = "__solid_ml_tpl_slot" ^ string_of_int id in
    let path = pexp_array ~loc [ eint ~loc insert_idx ] in
    let bind_text_call =
      pexp_apply ~loc
        (pexp_ident ~loc (lid "Html.Template.bind_text"))
        [ (Nolabel, evar ~loc inst_var);
          (Labelled "id", eint ~loc id);
          (Labelled "path", path) ]
    in
    pexp_let ~loc Nonrecursive
      [ value_binding ~loc ~pat:(pvar ~loc slot_var) ~expr:bind_text_call ]
      acc
  in

  let body_with_slots = List.fold_left bind_slot body slots_for_binding in

  let body_with_el =
    match attrs with
    | [] -> body_with_slots
    | _ ->
      pexp_let ~loc Nonrecursive
        [ value_binding ~loc ~pat:(pvar ~loc el_var) ~expr:bind_root_el_call ]
        body_with_slots
  in

  pexp_let ~loc Nonrecursive
    [ value_binding ~loc ~pat:(pvar ~loc template_var) ~expr:compile_call ]
    (pexp_let ~loc Nonrecursive
       [ value_binding ~loc ~pat:(pvar ~loc inst_var) ~expr:instantiate_call ]
       body_with_el)

let compile_tag_with_text ~(loc : Location.t) ~(tag : string)
    ~(thunk : Parsetree.expression) : Parsetree.expression =
  compile_tag_with_children ~loc ~tag ~children:[ Text_slot thunk ] ~attrs:[]
    ~static_props:[]

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
        | _ -> None))
  | _ -> None

(* tag compilation is implemented by [compile_tag_with_text]. *)
let transform_structure (structure : Parsetree.structure) : Parsetree.structure =
  let aliases = collect_tpl_aliases structure in
  let mapper =
    object
      inherit Ast_traverse.map as super

      method! expression expr =
        let expr = super#expression expr in
        match expr.pexp_desc with
        | Pexp_apply (_fn, args) ->
          (match head_ident expr with
           | None -> expr
           | Some longident ->
             (match extract_intrinsic_tag longident with
              | None -> expr
              | Some tag ->
                let children_arg =
                  List.find_map
                    (function
                      | (Asttypes.Labelled "children", e) -> Some e
                      | _ -> None)
                    args
                in
                 let extract_static_prop = function
                   | (Asttypes.Labelled "id", { pexp_desc = Pexp_constant (Pconst_string (s, _, _)); _ }) ->
                     Some (Static_id s)
                   | (Asttypes.Labelled "class_", { pexp_desc = Pexp_constant (Pconst_string (s, _, _)); _ }) ->
                     Some (Static_class s)
                   | _ -> None
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
                         || Option.is_some (extract_tpl_attr_binding ~aliases (snd arg)))
                     args
                 in
                 (match (children_arg, other_args_ok) with
                  | (Some children_expr, true) ->
                    (match list_of_expr children_expr with
                     | Some children_list ->
                       let supported_parts = ref [] in
                       let allow_whitespace_normalization =
                         match tag with
                         | "pre" | "code" -> false
                         | _ -> true
                       in
                       let supported =
                         List.for_all
                           (fun child ->
                             match extract_static_text_literal child with
                             | Some lit
                               when allow_whitespace_normalization
                                    && is_formatting_whitespace lit ->
                               true
                             | Some lit ->
                               supported_parts := Static_text lit :: !supported_parts;
                               true
                             | None ->
                               (match extract_tpl_text_thunk ~aliases child with
                                | Some thunk ->
                                  supported_parts := Text_slot thunk :: !supported_parts;
                                  true
                                | None -> false))
                           children_list
                       in
                       let parts = List.rev !supported_parts in
                       let has_text_slot =
                         List.exists
                           (function
                             | Text_slot _ -> true
                             | Static_text _ -> false)
                           parts
                       in
                       let has_dynamic = has_text_slot || attr_bindings <> [] in
                       if supported && has_dynamic then
                         compile_tag_with_children ~loc:expr.pexp_loc ~tag
                           ~children:parts ~attrs:attr_bindings
                           ~static_props:static_props
                       else expr
                     | _ -> expr)

                  | _ -> expr)))

        | _ -> expr
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
