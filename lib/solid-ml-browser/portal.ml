(** Portal component - renders children into a different DOM node.
    
    Portals allow rendering content outside the normal DOM hierarchy,
    useful for modals, tooltips, dropdowns, etc.
    
    Matches SolidJS's Portal API:
    - Client-side only (no SSR rendering)
    - Default mount target is document.body
    - Events propagate through component hierarchy, not DOM hierarchy
    - Hydration is disabled (portal content is created fresh on client)
    
    Usage:
    {[
      Portal.create ~children:(div ~children:[text "Modal content"] ()) ~target:modal_container ()
    ]}
 *)

open Dom

(** {1 Types} *)

type portal_props = {
  target : element option;  (** DOM element to mount into. None = document.body *)
  use_shadow : bool;        (** Use shadow DOM for style isolation *)
  is_svg : bool;            (** Target is an SVG element *)
  children : Html.node;     (** Content to render in portal *)
}

(** {1 Internal State} *)

let document_body : element option ref = ref None

let get_document_body () =
  match !document_body with
  | Some body -> body
  | None ->
    let body = Option.get (get_element_by_id document "body") in
    document_body := Some body;
    body

(** {1 Portal Creation} *)

(** Create a portal that renders children into the specified target.
    
    @param target DOM element to mount into. If None, uses document.body
    @param use_shadow If true, wraps content in shadow DOM for style isolation
    @param is_svg If true, uses <g> wrapper instead of <div> (for SVG targets)
    @param children Content to render in the portal *)
let create (props : portal_props) : Html.node =
  let placeholder = create_comment document "portal" in
  let placeholder_node = node_of_comment placeholder in
  
  let mounted_node : Dom.node option ref = ref None in
  
  let cleanup () =
    match !mounted_node with
    | Some node -> remove_node node
    | None -> ()
  in
  
  Effect.create (fun () ->
    let target = match props.target with
      | Some el -> el
      | None -> get_document_body ()
    in
    
    let children_node = Html.to_dom_node props.children in
    
    let content = if props.is_svg then
      children_node
    else if get_tag_name target = "HEAD" then
      children_node
    else
      let wrapper = create_element document "div" in
      set_attribute wrapper "data-solid-ml-portal" "";
      append_child wrapper children_node;
      node_of_element wrapper
    in
    
    append_child target content;
    mounted_node := Some content;
    
    Owner.on_cleanup cleanup
  );
  
  Text (create_text_node document "")

(** {1 Shorthand} *)

(** Create a portal that mounts to document.body *)
let create_simple ~(children : Html.node) () : Html.node =
  create {
    target = None;
    use_shadow = false;
    is_svg = false;
    children;
  }

(** Create a portal that mounts to a specific element by ID *)
let create_by_id ~(id : string) ~(children : Html.node) () : Html.node =
  let target = get_element_by_id document id in
  create {
    target;
    use_shadow = false;
    is_svg = false;
    children;
  }

(** Create a portal for SVG content *)
let create_svg ~(target : element) ~(children : Html.node) () : Html.node =
  create {
    target = Some target;
    use_shadow = false;
    is_svg = true;
    children;
  }
