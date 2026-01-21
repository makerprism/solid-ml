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

let render_page root path =
  let page =
    if String.length path >= 8 && String.sub path 0 8 = "/counter" then
      C.Counter (parse_count ())
    else if path = "/todos" then
      C.Todos Ssr_server_shared.Components.sample_todos
    else
      C.Home
  in
  let _dispose = Render.render root (fun () -> C.app ~page ()) in
  ()

let setup_links root =
  let links = Dom.query_selector_all (Dom.document ()) "a[href]" in
  List.iter (fun link ->
    match Dom.get_attribute link "data-setup" with
    | Some _ -> ()
    | None ->
      Dom.set_attribute link "data-setup" "true";
      Dom.add_event_listener link "click" (fun evt ->
        match Dom.get_attribute link "href" with
        | Some href when String.length href > 0 && href.[0] = '/' ->
          Dom.prevent_default evt;
          Dom.push_state href;
          render_page root href
        | _ -> ())
  ) links

let () =
  match get_element "app" with
  | None -> Dom.error "Could not find #app element for hydration"
  | Some root ->
    let path = Dom.get_pathname () in
    render_page root path;
    setup_links root;
    Dom.on_popstate (fun _evt ->
      let next_path = Dom.get_pathname () in
      render_page root next_path;
      setup_links root
    )
