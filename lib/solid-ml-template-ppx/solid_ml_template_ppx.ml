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

let supported_subset = "(none)"

let impl (structure : Parsetree.structure) : Parsetree.structure =
  match contains_tpl_markers structure with
  | None -> structure
  | Some (loc, name) ->
    Location.raise_errorf ~loc
      "solid-ml-template-ppx: found Tpl.%s, but template compilation is not implemented yet.\n\n\
       Current supported subset: %s.\n\
       Next steps: implement template compilation for intrinsic tags + Tpl.text.\n\n\
       If you did not intend to use the template compiler here, remove the Tpl.* marker.\n\
       If you intended to use it, ensure this file is built with:\n\
         (preprocess (pps mlx solid-ml-template-ppx))\n\n\
       Note: without the PPX rewrite, Tpl markers will also fail to typecheck\n\
       when used as normal nodes/attrs/events (marker-type design: Tpl.t)."
      name supported_subset

let () =
  Driver.register_transformation
    ~impl
    "solid-ml-template-ppx"
