(** SSR Server Example - Client Hydration

    Build with: make example-ssr-client
*)

open Solid_ml_browser

module C = Ssr_server_shared.Components.App (Solid_ml_browser.Env)

let get_element id = Dom.get_element_by_id (Dom.document ()) id

let parse_count () =
  match Dom.get_search () with
  | "" -> 0
  | search ->
    let search = String.sub search 1 (String.length search - 1) in
    let parts = String.split_on_char '&' search in
    let count_part = List.find_opt (fun s ->
      String.length s > 6 && String.sub s 0 6 = "count="
    ) parts in
    match count_part with
    | Some s ->
      (try int_of_string (String.sub s 6 (String.length s - 6))
       with _ -> 0)
    | None -> 0

let rec render_page root path =
  let page =
    if String.length path >= 8 && String.sub path 0 8 = "/counter" then
      C.Counter (parse_count ())
    else if path = "/todos" then
      C.Todos Ssr_server_shared.Components.sample_todos
    else
      C.Home
  in
  let _dispose = Render.render root (fun () -> C.app ~page ()) in
  bind_links root

and bind_links root =
  let _dispose =
    Navigation.bind_links ~root ~on_navigate:(fun href -> render_page root href) ()
  in
  ()

let () =
  match get_element "app" with
  | None -> Dom.error "Could not find #app element for hydration"
  | Some root ->
    let path = Dom.get_pathname () in
    render_page root path;
    let _dispose =
      Navigation.bind_popstate ~on_navigate:(fun next_path ->
        render_page root next_path
      ) ()
    in
    ()
