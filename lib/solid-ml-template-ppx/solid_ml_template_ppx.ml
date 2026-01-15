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

let supported_subset = "Html.div ~children:[Tpl.text _] ()"

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

let is_div_longident (longident : Longident.t) : bool =
  match List.rev (longident_to_list longident) with
  | [ "div" ] -> true
  | "div" :: "Html" :: _ -> true
  | _ -> false

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

let compile_div_with_text ~(loc : Location.t) ~(thunk : Parsetree.expression)
    : Parsetree.expression =
  let open Ast_builder.Default in
  let lid s = { loc; txt = Longident.parse s } in
  let template_var = "__solid_ml_tpl_template" in
  let inst_var = "__solid_ml_tpl_inst" in
  let slot_var = "__solid_ml_tpl_slot0" in
  let segments = pexp_array ~loc [ estring ~loc "<div>"; estring ~loc "</div>" ] in
  let slot_kinds = pexp_array ~loc [ pexp_variant ~loc "Text" None ] in
  let path0 = pexp_array ~loc [ eint ~loc 0 ] in
  let compile_call =
    pexp_apply ~loc
      (pexp_ident ~loc (lid "Html.Template.compile"))
      [ (Labelled "segments", segments); (Labelled "slot_kinds", slot_kinds) ]
  in
  let instantiate_call =
    pexp_apply ~loc
      (pexp_ident ~loc (lid "Html.Template.instantiate"))
      [ (Nolabel, evar ~loc template_var) ]
  in
  let bind_text_call =
    pexp_apply ~loc
      (pexp_ident ~loc (lid "Html.Template.bind_text"))
      [ (Nolabel, evar ~loc inst_var);
        (Labelled "id", eint ~loc 0);
        (Labelled "path", path0) ]
  in
  let thunk_call = pexp_apply ~loc thunk [ (Nolabel, eunit ~loc) ] in
  let set_text_call =
    pexp_apply ~loc
      (pexp_ident ~loc (lid "Html.Template.set_text"))
      [ (Nolabel, evar ~loc slot_var); (Nolabel, thunk_call) ]
  in
  let effect_call =
    pexp_apply ~loc
      (pexp_ident ~loc (lid "Effect.create"))
      [ (Nolabel, pexp_fun ~loc Nolabel None (punit ~loc) set_text_call) ]
  in
  let root_call =
    pexp_apply ~loc
      (pexp_ident ~loc (lid "Html.Template.root"))
      [ (Nolabel, evar ~loc inst_var) ]
  in
  let vb_template =
    value_binding ~loc ~pat:(pvar ~loc template_var) ~expr:compile_call
  in
  let vb_inst = value_binding ~loc ~pat:(pvar ~loc inst_var) ~expr:instantiate_call in
  let vb_slot = value_binding ~loc ~pat:(pvar ~loc slot_var) ~expr:bind_text_call in
  pexp_let ~loc Nonrecursive [ vb_template ]
    (pexp_let ~loc Nonrecursive [ vb_inst ]
       (pexp_let ~loc Nonrecursive [ vb_slot ]
          (pexp_sequence ~loc effect_call root_call)))

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
           | Some longident when is_div_longident longident ->
             let children_arg =
               List.find_map
                 (function
                   | (Asttypes.Labelled "children", e) -> Some e
                   | _ -> None)
                 args
             in
             let other_args_ok =
               List.for_all
                 (function
                   | (Asttypes.Labelled "children", _) -> true
                   | (Asttypes.Nolabel, e) -> is_unit_expr e
                   | _ -> false)
                 args
             in
             (match (children_arg, other_args_ok) with
              | (Some children_expr, true) ->
                (match list_of_expr children_expr with
                 | Some [ child ] ->
                   (match extract_tpl_text_thunk ~aliases child with
                    | Some thunk -> compile_div_with_text ~loc:expr.pexp_loc ~thunk
                    | None -> expr)
                 | _ -> expr)
              | _ -> expr)
           | _ -> expr)
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
