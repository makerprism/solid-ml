(** Simple SPA navigation helpers. *)

type dispose = unit -> unit

type history_mode = [ `Push | `Replace | `None ]

let is_internal_href href =
  String.length href > 0 && href.[0] = '/'

let bind_links ?root ?(selector = "a[href]") ?(history = `Push) ~on_navigate () : dispose =
  let elements =
    match root with
    | Some el -> Dom.query_selector_all_within el selector
    | None -> Dom.query_selector_all (Dom.document ()) selector
  in
  let handlers =
    List.filter_map
      (fun link ->
        match Dom.get_attribute link "data-spa-bound" with
        | Some _ -> None
        | None ->
          Dom.set_attribute link "data-spa-bound" "true";
          let handler evt =
            match Dom.get_attribute link "href" with
            | Some href when is_internal_href href ->
              Dom.prevent_default evt;
              let history_mode =
                match Dom.get_attribute link "data-spa-replace" with
                | Some _ -> `Replace
                | None -> history
              in
              (match history_mode with
               | `Push -> Dom.push_state href
               | `Replace -> Dom.replace_state href
               | `None -> ());
              on_navigate href
            | _ -> ()
          in
          Dom.add_event_listener link "click" handler;
          Some (link, handler))
      elements
  in
  fun () ->
    List.iter (fun (link, handler) -> Dom.remove_event_listener link "click" handler) handlers

let bind_popstate ~on_navigate () : dispose =
  let handler _evt =
    let path = Dom.get_pathname () in
    on_navigate path
  in
  Dom.on_popstate handler;
  fun () -> Dom.off_popstate handler

let bind_spa ?root ?selector ?history ~on_navigate () : dispose =
  let dispose_links = bind_links ?root ?selector ?history ~on_navigate () in
  let dispose_popstate = bind_popstate ~on_navigate () in
  fun () ->
    dispose_links ();
    dispose_popstate ()
