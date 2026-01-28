open Solid_ml_ssr

module Router_components = Solid_ml_router.Components.Make(Solid_ml_ssr.Html)
module Shared = Shared_components.Make(Solid_ml_ssr.Html)(Router_components)(struct
  let base = "/browser_router"
end)

let base_path = "/browser_router"

let strip_base path =
  let base_len = String.length base_path in
  if String.length path >= base_len && String.sub path 0 base_len = base_path then
    let rest = String.sub path base_len (String.length path - base_len) in
    if rest = "" then "/" else rest
  else
    path

let css = {|
* { box-sizing: border-box; }
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  margin: 0;
  padding: 0;
  background: #f5f5f5;
  color: #333;
}
.app {
  max-width: 800px;
  margin: 0 auto;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}
header {
  background: white;
  padding: 20px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}
header h1 { margin: 0 0 16px 0; font-size: 1.5rem; }
.nav { display: flex; gap: 8px; flex-wrap: wrap; }
.nav a {
  padding: 8px 16px;
  text-decoration: none;
  color: #666;
  border-radius: 4px;
  transition: all 0.2s;
}
.nav a:hover { background: #f0f0f0; color: #333; }
.nav a.active { background: #4a90d9; color: white; }
main { flex: 1; padding: 24px 20px; }
.page {
  background: white;
  padding: 24px;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}
.page h2 { margin-top: 0; color: #333; }
.page h3 { margin-top: 24px; margin-bottom: 12px; color: #555; }
.page p { line-height: 1.6; color: #555; }
.page ul { line-height: 1.8; }
.page a { color: #4a90d9; }
.page a:hover { text-decoration: none; }
.user-list { list-style: none; padding: 0; }
.user-list li { margin: 8px 0; }
.user-list a {
  display: inline-block;
  padding: 8px 16px;
  background: #f5f5f5;
  border-radius: 4px;
  text-decoration: none;
  color: #333;
  transition: all 0.2s;
}
.user-list a:hover { background: #4a90d9; color: white; }
.counter-display {
  font-size: 1.25rem;
  margin: 20px 0;
  padding: 20px;
  background: #f5f5f5;
  border-radius: 8px;
}
.counter-display p { margin: 8px 0; }
.buttons { display: flex; gap: 10px; }
.btn {
  padding: 10px 20px;
  font-size: 16px;
  border: none;
  border-radius: 4px;
  background: #4a90d9;
  color: white;
  cursor: pointer;
  transition: background 0.2s;
}
.btn:hover { background: #357abd; }
.btn-secondary { background: #888; }
.btn-secondary:hover { background: #666; }
.error-page { text-align: center; }
.error-page h2 { color: #e74c3c; }
footer {
  padding: 20px;
  text-align: center;
  color: #888;
  font-size: 0.875rem;
}
footer a { color: #4a90d9; }
|}

let render_page ~path =
  let app_html =
    Render.to_string (fun () ->
      Router_components.provide ~initial_path:path ~routes:Shared.config_routes (fun () ->
        Shared.app ()
      ))
  in
  "<!DOCTYPE html>\n" ^
  "<html lang=\"en\">\n" ^
  "<head>\n" ^
  "  <meta charset=\"UTF-8\">\n" ^
  "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n" ^
  "  <title>solid-ml Router Demo</title>\n" ^
  "  <style>" ^ css ^ "</style>\n" ^
  "</head>\n" ^
  "<body>\n" ^
  "  <div id=\"app\">" ^ app_html ^ "</div>\n" ^
  "  <script type=\"module\" src=\"" ^ base_path ^ "/dist/router_demo.js\"></script>\n" ^
  "</body>\n" ^
  "</html>\n"

let handle_request req =
  let path = Dream.target req |> strip_base in
  Dream.html (render_page ~path)

let () =
  let dist_dir = "examples/browser_router/dist" in
  Dream.run
  @@ Dream.logger
  @@ Dream.router [
    Dream.get (base_path ^ "/dist/**") (Dream.static dist_dir);
    Dream.get (base_path ^ "") handle_request;
    Dream.get (base_path ^ "/**") handle_request;
  ]
