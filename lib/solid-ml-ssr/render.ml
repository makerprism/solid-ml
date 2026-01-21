(** Server-side rendering utilities. *)

let reset () =
  Html.reset_hydration_keys ()

let to_string component =
  Solid_ml.Runtime.Unsafe.run (fun () ->
    reset ();
    let node = ref (Html.text "") in
    let dispose = Solid_ml.Owner.Unsafe.create_root (fun () ->
      node := component ()
    ) in
    let result = Html.to_string !node in
    dispose ();
    result
  )

let to_document component =
  Solid_ml.Runtime.Unsafe.run (fun () ->
    reset ();
    let node = ref (Html.text "") in
    let dispose = Solid_ml.Owner.Unsafe.create_root (fun () ->
      node := component ()
    ) in
    let result = Html.render_document !node in
    dispose ();
    result
  )

let get_hydration_script () =
  (* For now, return empty script. Will be populated when we add state serialization *)
  "<script>window.__SOLID_ML_DATA__ = {};</script>"
