open Ppxlib

let known_tpl_markers =
  [ "text"; "attr"; "attr_opt"; "class_list"; "on"; "show"; "each_keyed" ]

let is_known_marker fn = List.exists (String.equal fn) known_tpl_markers

let tpl_marker_name (longident : Longident.t) : string option =
  let rec to_list acc = function
    | Longident.Lident s -> s :: acc
    | Longident.Ldot (t, s) -> to_list (s :: acc) t
    | Longident.Lapply _ -> []
  in
  match List.rev (to_list [] longident) with
  | [ "Solid_ml_template_runtime"; "Tpl"; fn ] when is_known_marker fn -> Some fn
  | [ "Tpl"; fn ] when is_known_marker fn -> Some fn
  | _ -> None

let contains_tpl_markers (structure : Parsetree.structure) : (Location.t * string) option =
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
        (match expr.pexp_desc with
         | Pexp_ident { txt = longident; _ } ->
           (match tpl_marker_name longident with
            | Some name -> record expr.pexp_loc name
            | None -> ())
         | Pexp_apply (fn, _args) ->
           (match fn.pexp_desc with
            | Pexp_ident { txt = longident; _ } ->
              (match tpl_marker_name longident with
               | Some name -> record expr.pexp_loc name
               | None -> ())
            | _ -> ())
         | _ -> ());
        super#expression expr
    end
  in
  iter#structure structure;
  !found

let impl (structure : Parsetree.structure) : Parsetree.structure =
  match contains_tpl_markers structure with
  | None -> structure
  | Some (loc, name) ->
    Location.raise_errorf ~loc
      "solid-ml-template-ppx: found Tpl.%s, but template compilation is not implemented yet.\n\n\
       Current supported subset: (none).\n\
       Next steps: implement template compilation for intrinsic tags + Tpl.text.\n\n\
       If you did not intend to use the template compiler here, remove the Tpl.* marker.\n\
       If you intended to use it, ensure this file is built with:\n\
         (preprocess (pps mlx solid-ml-template-ppx))"
      name

let () =
  Driver.register_transformation
    ~impl
    "solid-ml-template-ppx"
