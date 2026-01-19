open Solid_ml_browser

module C = Template_counter_shared.Components.App (Solid_ml_browser.Env)

let () =
  match Dom.get_element_by_id (Dom.document ()) "app" with
  | None -> Dom.error "template_counter: missing #app"
  | Some root ->
    let _dispose = Render.render root (fun () -> C.view ()) in
    ()
