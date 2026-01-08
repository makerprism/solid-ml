open Solid_ml
module Html = Solid_ml_ssr.Html
module Render = Solid_ml_ssr.Render

let layout ~title ~initial_count content =
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
        title ~children:[text title] ();
        link ~rel:"stylesheet" ~href:"/static/styles.css" ()
      ] ();
      body ~children:(content @ extra_scripts) ()
    ] ()
  )

let counter_component ~initial =
  Html.(
    main ~class_:"app" ~children:[
      h1 ~children:[text "solid-ml SSR + Hydration"] ();
      p ~children:[text "This counter was rendered on the server and hydrated in the browser."] ();
      div ~class_:"counter" ~children:[
        div ~id:"counter-value" ~class_:"counter-value" ~children:[text (string_of_int initial)] ();
        div ~class_:"buttons" ~children:[
          button ~id:"decrement" ~class_:"btn" ~children:[text "-"] ();
          button ~id:"increment" ~class_:"btn" ~children:[text "+"] ();
          button ~id:"reset" ~class_:"btn" ~children:[text "Reset"] ();
        ] ();
        input ~type_:"hidden" ~id:"counter-initial" ~value:(string_of_int initial) ();
      ] ();
      Html.Svg.svg
        ~viewBox:"0 0 120 120"
        ~width:"180"
        ~height:"180"
        ~children:[
          Html.Svg.circle
            ~cx:"60"
            ~cy:"60"
            ~r:"50"
            ~fill:"#4f46e5"
            ~children:[]
            ();
          Html.Svg.text_
            ~x:"60"
            ~y:"68"
            ~fill:"white"
            ~style:"font-size:24px; text-anchor:middle; font-family:system-ui;"
            ~children:[text "solid-ml"] ()
        ]
        ();
      p ~id:"hydration-status" ~class_:"status" ~children:[text "Waiting for hydration..."] ();
      p ~class_:"info" ~children:[
        text "Try editing the counter controls. The SVG badge stays in sync thanks to client hydration.";
      ] ()
    ] ()
  )

let page ~initial_count =
  let content = [counter_component ~initial:initial_count] in
  layout ~title:"solid-ml SSR Hydration Demo" ~initial_count content

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
