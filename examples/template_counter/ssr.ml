open Solid_ml_ssr

module C = Template_counter_shared.Components.App (Solid_ml_ssr.Env)

let () =
  let html = Render.to_string (fun () -> C.view ()) in
  print_endline html
