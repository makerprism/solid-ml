(** SSR rendering helpers for solid-ml-router resources. *)

open Solid_ml_router

let render_simple ?(error_to_string=(fun _ -> "Resource error")) ~ready resource =
  Resource.render
    ~loading:(fun () -> Html.text "Loading...")
    ~error:(fun err ->
      Html.p ~children:[Html.text ("Error: " ^ error_to_string err)] ())
    ~ready
    resource
