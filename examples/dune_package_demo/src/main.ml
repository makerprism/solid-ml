module Html = Solid_ml_ssr.Html
module Render = Solid_ml_ssr.Render

let app_view () =
  Html.(
    html ~children:[
      head ~children:[
        title ~children:[text "Solid-ML Dune Demo"] ()
      ] ();
      body ~class_:"app" ~children:[
        h1 ~children:[text "Hello from Solid-ML"] ();
        p ~children:[text "This page was rendered with dune package management."] ();
        Html.Svg.svg
          ~viewBox:"0 0 100 100"
          ~width:"120"
          ~height:"120"
          ~children:[
            Html.Svg.circle
              ~cx:"50"
              ~cy:"50"
              ~r:"40"
              ~fill:"#4f46e5"
              ~children:[]
              ();
            Html.Svg.text_
              ~x:"50"
              ~y:"55"
              ~fill:"white"
              ~style:"font-size:16px; text-anchor:middle"
              ~children:[text "SVG"] ()
          ]
          ()
      ] ()
    ] ()
  )

let () =
  let html_output = Render.to_document app_view in
  print_endline html_output
