module Html = Solid_ml_ssr.Html
module Render = Solid_ml_ssr.Render
module C = Ssr_hydration_shared.Components.App (Solid_ml_ssr.Env)

let layout ~page_title ~initial_count content =
  let extra_scripts =
    Html.[
      script ~children:[
        text (Printf.sprintf "window.__INITIAL_COUNT__ = %d;" initial_count)
      ] ();
      script ~type_:"module" ~src:"/static/client.js" ~children:[] ()
    ]
  in
  Html.(
    html ~lang:"en" ~children:[
      head ~children:[
        meta ~charset:"utf-8" ();
        meta ~name:"viewport" ~content:"width=device-width, initial-scale=1" ();
        title ~children:[text page_title] ();
        link ~rel:"stylesheet" ~href:"/static/styles.css" ()
      ] ();
      body ~children:(content @ extra_scripts) ()
    ] ()
  )

let page ~initial_count =
  let content = [C.view ~initial:initial_count ()] in
  layout ~page_title:"solid-ml-server SSR Hydration Demo" ~initial_count content

let render counter = Render.to_document (fun () -> page ~initial_count:counter)

let static_dir () =
  match Sys.getenv_opt "STATIC_DIR" with
  | Some dir -> dir
  | None ->
      if Sys.file_exists "examples/ssr_hydration_docker/static" then
        "examples/ssr_hydration_docker/static"
      else
        "static"

let handle_root _req =
  let initial = Random.int 20 in
  Dream.html (render initial)

let () =
  Random.self_init ();
  let port =
    match Sys.getenv_opt "PORT" with
    | Some v -> (try int_of_string v with _ -> 8080)
    | None -> 8080
  in
  let static_directory = static_dir () in
  Printf.printf "Serving static assets from %s\n" static_directory;
  Printf.printf "Starting server on http://0.0.0.0:%d\n%!" port;
  Dream.run ~interface:"0.0.0.0" ~port
  @@ Dream.logger
  @@ Dream.router [
       Dream.get "/" handle_root;
       Dream.get "/static/**" (Dream.static static_directory);
     ]
