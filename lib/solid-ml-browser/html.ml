(** DOM element creation functions.
    
    These functions mirror the solid-ml-html API but create actual DOM nodes
    instead of HTML strings. This allows the same component code to work on
    both server (generating HTML) and client (creating DOM).
 *)

[@@@warning "-32"] (* Allow unused portal function *)

open Dom

type 'a signal = 'a Reactive_core.signal
type event = Dom.event

let svg_namespace = "http://www.w3.org/2000/svg"

(** {1 Node Types} *)

(** A node that can be rendered to the DOM *)
type node =
  | Element of element
  | Text of text_node
  | Fragment of document_fragment
  | Empty

module Internal_template : Solid_ml_template_runtime.TEMPLATE
  with type node := node
   and type event := event
   and type element = Dom.element = struct
  type template = {
    container : element;
    root_tag : string;
  }

  type instance = {
    root_node : Dom.node;
    root_repr : [ `Element of Dom.element | `Fragment of document_fragment ];
  }

  type text_slot = text_node

  type keyed_item = {
    start_ : Dom.node;
    stop : Dom.node;
    root_el : Dom.element option;
    mutable dispose : unit -> unit;
    mutable attached : bool;
  }

  type keyed_state = {
    map : (string, keyed_item) Dom.js_map;
    mutable order : string list;
  }

  type nodes_slot = {
    parent : Dom.element;
    opening : Dom.node;
    closing : Dom.node;
    keyed : keyed_state option ref;
  }

  type element = Dom.element

  let build_html (segments : string array) (slot_kinds : Solid_ml_template_runtime.slot_kind array) : string =
    if Array.length segments <> Array.length slot_kinds + 1 then
      invalid_arg "Solid_ml_browser.Html.Internal_template.compile: segments length must be slot_kinds length + 1";
    let buf = Buffer.create 256 in
    Buffer.add_string buf segments.(0);
    for i = 0 to Array.length slot_kinds - 1 do
       (match slot_kinds.(i) with
        | `Attr ->
          (* For CSR, emit an empty attribute value; bindings will set the real value. *)
          Buffer.add_string buf ""
        | `Text ->
          (* Emit nothing; bind_text will create/insert the text node by path. *)
          ()
        | `Nodes ->
          (* Emit nothing; bind_nodes/set_nodes will manage the region. *)
          ());

      Buffer.add_string buf segments.(i + 1)
    done;
    Buffer.contents buf

  let compile ~segments ~slot_kinds =
    let html = build_html segments slot_kinds in
    let el = create_element (document ()) "div" in
    set_inner_html el html;
    (* Compiled templates must have exactly one root element so that hydration
       paths can be relative to the same root on CSR and hydration. *)
    let children = get_child_nodes el in
    if Array.length children <> 1 || not (is_element children.(0)) then
      invalid_arg
        (Printf.sprintf
           "Solid_ml_browser.Html.Internal_template.compile: expected exactly one root element (got %d). Hint: compiled templates cannot have fragments or top-level text nodes."
           (Array.length children));
    let root_el = element_of_node children.(0) in
    { container = el; root_tag = get_tag_name root_el }

  let rec normalize_for_hydration ~(root : Dom.element) ~(expected_tag : string) : unit =
    let actual = get_tag_name root in
    if actual <> expected_tag then
      invalid_arg
        (Printf.sprintf
           "Solid_ml_browser.Html.Template: root tag mismatch (expected %s, got %s)."
           expected_tag actual);

    (* Normalize server-rendered DOM shape for compiled templates.

       The template PPX emits paired SolidJS-style comment markers "<!--#-->" around
       each text slot. When SSR renders a non-empty slot, the browser parses:

         <!--#-->TEXT<!--#-->

       as [comment, text, comment]. The compiler's path model intentionally counts
       only the marker nodes (CSR instantiation has no slot text node yet).

       During hydration we remove any text nodes between paired "#" markers so
       [bind_element] paths remain consistent with CSR. The slot text will be
       re-inserted by [bind_text] + [set_text]. *)
    let is_text_marker (node : Dom.node) : bool =
      is_comment node && comment_data (comment_of_node node) = "#"
    in

    let is_nodes_marker (node : Dom.node) : bool =
      is_comment node && comment_data (comment_of_node node) = "$"
    in

    let rec normalize_between_markers (parent : Dom.element) : unit =
      let rec walk (node_opt : Dom.node option) : unit =
        match node_opt with
        | None -> ()
        | Some node ->
          (if is_element node then normalize_between_markers (element_of_node node));

          if is_text_marker node then (
            (* Collect consecutive text siblings immediately after this marker. *)
            let rec collect_texts acc (cur : Dom.node option) =
              match cur with
              | Some n when is_text n ->
                collect_texts (n :: acc) (node_next_sibling n)
              | other -> (List.rev acc, other)
            in
            let texts, after = collect_texts [] (node_next_sibling node) in
            (match (texts, after) with
             | (_ :: _, Some closing) when is_text_marker closing ->
               List.iter remove_node texts
             | _ -> ()))
          else if is_nodes_marker node then (
            (* Do not clear SSR content for node regions; keep it for adoption.
               Just skip to the closing marker. *)
            let rec find_closing (cur : Dom.node option) : Dom.node option =
              match cur with
              | None -> None
              | Some n when is_nodes_marker n -> Some n
              | Some n -> find_closing (node_next_sibling n)
            in
            match find_closing (node_next_sibling node) with
            | None -> walk (node_next_sibling node)
            | Some closing -> walk (node_next_sibling closing))
          else
            walk (node_next_sibling node)
      in
      walk (get_first_child parent)
    in

    normalize_between_markers root

  and instantiate template =
    if Hydration.is_hydrating () then (
      (* Prefer an explicitly provided root (used for keyed-item attachment).
         Otherwise adopt from the element hydration cursor.

         Important: in hydration mode, silently cloning a new subtree defeats the
         purpose of hydration and can cause duplicate DOM. We fail loudly if we
         cannot adopt. *)
      let adopted_root_opt =
        match Hydration.pop_template_root () with
        | Some root -> Some root
        | None -> Hydration.adopt_element template.root_tag
      in
       match adopted_root_opt with
       | Some root ->
         normalize_for_hydration ~root ~expected_tag:template.root_tag;
         { root_node = node_of_element root; root_repr = `Element root }
       | None ->
         invalid_arg
           (Printf.sprintf
              "Solid_ml_browser.Html.Internal_template.instantiate: hydration mode but could not adopt a <%s> root element"
              template.root_tag))
    else
      let clone = clone_node template.container true in
      let children = get_child_nodes clone in
      if Array.length children <> 1 || not (is_element children.(0)) then
        invalid_arg
          (Printf.sprintf
             "Solid_ml_browser.Html.Internal_template.instantiate: expected exactly one root element (got %d)."
             (Array.length children));
      let root = children.(0) in
      { root_node = root; root_repr = `Element (element_of_node root) }

  let root inst =
    match inst.root_repr with
    | `Fragment frag -> Fragment frag
    | `Element el -> Element el

  let is_nodes_marker (node : Dom.node) : bool =
    is_comment node && comment_data (comment_of_node node) = "$"

  (* Virtual child indexing for compiled templates.

     Compiled templates model node-region slots using paired <!--$--> markers.
     During CSR there are no nodes between those markers; during hydration there
     may be SSR-rendered content (including keyed list item markers).

     To keep compiler-generated paths stable, we treat all nodes between paired
     <!--$--> markers as invisible for indexing purposes, while still keeping
     them in the DOM for adoption. *)
  let virtual_child_at (children : Dom.node array) (target_idx : int) : Dom.node option =
    let v = ref 0 in
    let i = ref 0 in
    let len = Array.length children in

    let in_region = ref false in
    let closing_idx = ref (-1) in

    let find_next_nodes_marker from_idx =
      let j = ref from_idx in
      while !j < len && not (is_nodes_marker children.(!j)) do
        incr j
      done;
      !j
    in

    let result = ref None in
    while !i < len && !result = None do
      let n = children.(!i) in
      if !v = target_idx then result := Some n;

      if is_nodes_marker n then (
        if (not !in_region) then (
          (* Opening marker: count it, then jump to the closing marker without
             counting any interior nodes. *)
          in_region := true;
          let close = find_next_nodes_marker (!i + 1) in
          closing_idx := close;
          incr v;
          if close < len then i := close else i := len
        ) else if !i = !closing_idx then (
          (* Closing marker: count it and continue normally. *)
          in_region := false;
          closing_idx := -1;
          incr v;
          incr i
        ) else (
          (* Unexpected marker inside region; treat as a normal node. *)
          incr v;
          incr i
        )
      ) else (
        incr v;
        incr i
      )
    done;

    !result

  let node_at (root : Dom.node) (path : int array) : Dom.node =
    let current = ref root in
    for depth = 0 to Array.length path - 1 do
      let children = node_child_nodes !current in
      let idx = path.(depth) in
      (match virtual_child_at children idx with
       | None ->
         invalid_arg
           (Printf.sprintf
              "Solid_ml_browser.Html.Template: path out of bounds at depth %d (idx=%d)"
              depth idx)
       | Some n -> current := n)
    done;
    !current

  let bind_text inst ~id:_ ~path =
    (* [path] is an insertion path. All but the last index locate the parent.
       The last index is the insertion position for the text node. *)
    if Array.length path = 0 then
      invalid_arg "Solid_ml_browser.Html.Internal_template.bind_text: empty path";
    let parent_path = Array.sub path 0 (Array.length path - 1) in
    let insert_idx = path.(Array.length path - 1) in
    let parent_node = node_at inst.root_node parent_path in
    if not (is_element parent_node) then
      invalid_arg
        (Printf.sprintf
           "Solid_ml_browser.Html.Internal_template.bind_text: parent is not an element (nodeType=%d)"
           (node_type parent_node));
    let parent_el = element_of_node parent_node in
    let children = get_child_nodes parent_el in
    let existing =
      match virtual_child_at children insert_idx with
      | Some n when is_text n -> Some (text_of_node n)
      | _ -> None
    in
    match existing with
    | Some t -> t
    | None ->
      let t = create_text_node (document ()) "" in
      let ref_node = virtual_child_at children insert_idx in
      insert_before parent_el (node_of_text t) ref_node;
      t

  let set_text (slot : text_slot) (value : string) =
    text_set_data slot value

  let bind_nodes inst ~id:_ ~path : nodes_slot =
    (* [path] is an insertion path whose last index points at the closing marker
       node for the region (typically the second <!--$-->). *)
    if Array.length path = 0 then
      invalid_arg "Solid_ml_browser.Html.Internal_template.bind_nodes: empty path";
    let parent_path = Array.sub path 0 (Array.length path - 1) in
    let closing_idx = path.(Array.length path - 1) in
    let parent_node = node_at inst.root_node parent_path in
    if not (is_element parent_node) then
      invalid_arg
        (Printf.sprintf
           "Solid_ml_browser.Html.Internal_template.bind_nodes: parent is not an element (nodeType=%d)"
           (node_type parent_node));
    let parent = element_of_node parent_node in
    let children = get_child_nodes parent in
    let closing =
      match virtual_child_at children closing_idx with
      | None -> invalid_arg "Solid_ml_browser.Html.Internal_template.bind_nodes: closing index out of bounds"
      | Some n -> n
    in
    let is_marker (n : Dom.node) =
      is_comment n && comment_data (comment_of_node n) = "$"
    in
    if not (is_marker closing) then
      invalid_arg "Solid_ml_browser.Html.Internal_template.bind_nodes: closing node is not a <!--$--> marker";

    let opening_idx =
      (* Find the previous <!--$--> marker before [closing]. *)
      let closing_real_idx =
        let idx = ref (-1) in
        for i = 0 to Array.length children - 1 do
          if children.(i) == closing then idx := i
        done;
        !idx
      in
      if closing_real_idx < 0 then -1
      else
        let idx = ref (-1) in
        for i = 0 to closing_real_idx - 1 do
          if is_marker children.(i) then idx := i
        done;
        !idx
    in
    if opening_idx < 0 then
      invalid_arg "Solid_ml_browser.Html.Internal_template.bind_nodes: could not find opening <!--$--> marker";
    let opening = children.(opening_idx) in
    { parent; opening; closing; keyed = ref None }

  let set_nodes (slot : nodes_slot) (value : node) : unit =
    (* Clear keyed state: we are no longer managing this region as a keyed list. *)
    (match !(slot.keyed) with
     | None -> ()
     | Some st ->
       List.iter
         (fun k ->
           match Dom.js_map_get_opt st.map k with
           | None -> ()
           | Some item -> item.dispose ())
         st.order;
       Dom.js_map_clear st.map;
       slot.keyed := None);
    (* Remove everything between markers. *)
    let rec clear_between () =
      match node_next_sibling slot.opening with
      | None -> ()
      | Some n when n == slot.closing -> ()
      | Some n ->
        remove_node n;
        clear_between ()
    in
    clear_between ();

    let to_dom_node (n : node) : Dom.node option =
      match n with
      | Element el -> Some (node_of_element el)
      | Text txt -> Some (node_of_text txt)
      | Fragment frag -> Some (node_of_fragment frag)
      | Empty -> None
    in

    let insert_one (n : node) =
      match to_dom_node n with
      | None -> ()
      | Some dom_n -> insert_before slot.parent dom_n (Some slot.closing)
    in

    (* Insert new content before the closing marker. *)
    insert_one value

  let bind_element inst ~id:_ ~path =
    let n = node_at inst.root_node path in
    if not (is_element n) then
      invalid_arg
        (Printf.sprintf
           "Solid_ml_browser.Html.Internal_template.bind_element: node is not an element (nodeType=%d)"
           (node_type n));
    element_of_node n

  let set_attr (el : element) ~name (value : string option) =
    match value with
    | Some v -> set_attribute el name v
    | None -> remove_attribute el name

  let on_ (el : element) ~event handler =
    add_event_listener el event handler

  let off_ (el : element) ~event handler =
    remove_event_listener el event handler

  let set_nodes_keyed (slot : nodes_slot) ~key ~(render : 'a -> node * (unit -> unit)) (items : 'a list) : unit =
    let state, is_new_state =
      match !(slot.keyed) with
      | Some s -> (s, false)
      | None ->
        let s = { map = Dom.js_map_create (); order = [] } in
        slot.keyed := Some s;
        (s, true)
    in

    let rec clear_between_markers opening closing =
      match node_next_sibling opening with
      | None -> ()
      | Some n when n == closing -> ()
      | Some n ->
        remove_node n;
        clear_between_markers opening closing
    in

    let rec nodes_in_range acc (cur : Dom.node option) (stop : Dom.node) =
      match cur with
      | None -> List.rev acc
      | Some n ->
        let acc = n :: acc in
        if n == stop then List.rev acc
        else nodes_in_range acc (node_next_sibling n) stop
    in

    let encode_key (s : string) : string =
      let buf = Buffer.create (String.length s * 2) in
      String.iter
        (fun c -> Buffer.add_string buf (Printf.sprintf "%02x" (Char.code c)))
        s;
      Buffer.contents buf
    in

    let make_item_markers (k_enc : string) : Dom.node * Dom.node =
      let doc = Dom.document () in
      let start_ = Dom.node_of_comment (Dom.create_comment doc ("k:" ^ k_enc)) in
      let stop = Dom.node_of_comment (Dom.create_comment doc "/k") in
      (start_, stop)
    in

     let is_keyed_start (node : Dom.node) : string option =
       if not (is_comment node) then None
       else
         let d = comment_data (comment_of_node node) in
         if String.length d >= 2 && String.sub d 0 2 = "k:" then
           Some (String.sub d 2 (String.length d - 2))
         else
           None
     in

     let is_keyed_stop (node : Dom.node) : bool =
       is_comment node && comment_data (comment_of_node node) = "/k"
     in

    let adopt_existing_keyed_ranges () : unit =
      (* Parse existing SSR content between $ markers into keyed_item ranges.
         We recognize: <!--k:HEXKEY--> ... <!--/k--> pairs.

         We also *remove* any stray nodes inside the region that are not part of
         a keyed range, so the first reactive reconciliation produces a clean
         region with predictable structure. *)
      let order_rev = ref [] in
      let rec walk cur =
        match cur with
        | None -> ()
        | Some n when n == slot.closing -> ()
        | Some n ->
          (match is_keyed_start n with
           | Some k_enc ->
             let rec find_stop c =
               match c with
               | None -> None
               | Some x when x == slot.closing -> None
               | Some x when is_keyed_stop x -> Some x
               | Some x -> find_stop (node_next_sibling x)
             in
             (match find_stop (node_next_sibling n) with
              | None ->
                (* Broken marker pair; drop the start marker and continue. *)
                let next = node_next_sibling n in
                remove_node n;
                walk next
              | Some stop ->
                order_rev := k_enc :: !order_rev;
                 let rec find_root (cur : Dom.node option) : Dom.element option =
                   match cur with
                   | None -> None
                   | Some x when x == stop -> None
                   | Some x -> if Dom.is_element x then Some (Dom.element_of_node x) else find_root (Dom.node_next_sibling x)
                 in
                 let root_el = find_root (Dom.node_next_sibling n) in
                 Dom.js_map_set_ state.map k_enc { start_ = n; stop; root_el; dispose = (fun () -> ()); attached = false };

                walk (node_next_sibling stop))
           | None ->
             (* Stray node (not within keyed markers); remove it. *)
             let next = node_next_sibling n in
             remove_node n;
             walk next)
      in
      walk (node_next_sibling slot.opening);
      state.order <- List.rev !order_rev
    in



    let move_range_before_closing (item : keyed_item) =
      let nodes = nodes_in_range [] (Some item.start_) item.stop in
      List.iter (fun n -> Dom.insert_before slot.parent n (Some slot.closing)) nodes
    in

    let remove_range (item : keyed_item) =
      let nodes = nodes_in_range [] (Some item.start_) item.stop in
      List.iter Dom.remove_node nodes
    in

    let insert_value_before_closing (value : node) =
      match value with
      | Empty -> ()
      | Element el -> Dom.insert_before slot.parent (Dom.node_of_element el) (Some slot.closing)
      | Text t -> Dom.insert_before slot.parent (Dom.node_of_text t) (Some slot.closing)
      | Fragment frag ->
        let children = Array.to_list (Dom.fragment_child_nodes frag) in
        List.iter (fun n -> Dom.insert_before slot.parent n (Some slot.closing)) children
    in

    (* If we are switching from an unkeyed region (set_nodes) to a keyed region:
       - during CSR, the region should be empty
       - during hydration, SSR content may exist; adopt it instead of clearing
         so we can preserve DOM nodes and avoid flicker. *)
    if is_new_state then (
      adopt_existing_keyed_ranges ();
      if Dom.js_map_size state.map = 0 then clear_between_markers slot.opening slot.closing);

    let new_keys = List.map (fun x -> encode_key (key x)) items in
    let new_key_set : (string, bool) Dom.js_map = Dom.js_map_create () in
    List.iter (fun k_enc -> Dom.js_map_set_ new_key_set k_enc true) new_keys;

    (* Remove items that disappeared (including their marker range). *)
    List.iter
      (fun old_k ->
        if not (Dom.js_map_has new_key_set old_k) then
          match Dom.js_map_get_opt state.map old_k with
          | None -> ()
          | Some it ->
            remove_range it;
            it.dispose ();
            ignore (Dom.js_map_delete state.map old_k))
      state.order;

     (* Ensure all new keys exist, creating marker ranges for new items. *)
     List.iter
       (fun item ->
         let k_enc = encode_key (key item) in
         match Dom.js_map_get_opt state.map k_enc with
         | Some _ -> ()
         | None ->
           let value, dispose = render item in
           let start_, stop = make_item_markers k_enc in
           Dom.insert_before slot.parent start_ (Some slot.closing);
           insert_value_before_closing value;
           Dom.insert_before slot.parent stop (Some slot.closing);
           Dom.js_map_set_ state.map k_enc { start_; stop; root_el = None; dispose; attached = true })
       items;

     (* Attach per-item ownership for adopted items.

        For items adopted from SSR, we have DOM already but no disposer.
        To bind cleanup semantics, we run [render] once under hydration with the
        adopted root pushed onto the template stack. If [render] does not adopt
        the expected root element, we immediately dispose it to avoid leaks. *)
     if Hydration.is_hydrating () then
       List.iter
         (fun item ->
           let k_enc = encode_key (key item) in
           match Dom.js_map_get_opt state.map k_enc with
           | None -> ()
           | Some it when it.attached -> ()
           | Some it ->
             (match it.root_el with
              | None -> it.attached <- true
               | Some root_el ->
                 Hydration.push_template_root root_el;
                 let v, dispose = render item in
                 (* If [render] did not consume the template root (by calling
                    Internal_template.instantiate), pop it to avoid leaking stack state.
                    If it did consume it, the stack top will differ. *)
                 (match Hydration.peek_template_root () with
                  | Some top when top == root_el -> ignore (Hydration.pop_template_root ())
                  | _ -> ());
                 (match v with
                  | Element el when el == root_el -> it.dispose <- dispose
                  | _ -> dispose ());
                 it.attached <- true)
         )
         items;




    (* Reorder items to match new order by moving ranges. *)
    List.iter
      (fun k_enc ->
        match Dom.js_map_get_opt state.map k_enc with
        | None -> ()
        | Some it -> move_range_before_closing it)
      new_keys;

    state.order <- new_keys

end

(** {1 Node Conversion} *)

(** Convert our node type to a DOM node for appending *)
let to_dom_node = function
  | Element el -> node_of_element el
  | Text txt -> node_of_text txt
  | Fragment frag -> node_of_fragment frag
  | Empty -> node_of_text (create_text_node (document ()) "")

(** Append a node to an element *)
let append_to_element parent child =
  append_child parent (to_dom_node child)

(** Append a node to a fragment *)
let append_to_fragment frag child =
  fragment_append_child frag (to_dom_node child)

(** {1 Attribute Helpers} *)

let set_opt_attr el name = function
  | Some v -> set_attribute el name v
  | None -> ()

let set_bool_attr el name value =
  if value then set_attribute el name ""
  else remove_attribute el name

(** Validate data-* attribute key.
    Per HTML5 spec, data attribute names must:
    - Contain only ASCII letters, digits, hyphens, underscores, and periods
    - Not start with "xml" (case-insensitive)
    Invalid keys are silently filtered out for security. *)
let is_valid_data_key s =
  let len = String.length s in
  if len = 0 then false
  else if len >= 3 && 
    (s.[0] = 'x' || s.[0] = 'X') && 
    (s.[1] = 'm' || s.[1] = 'M') && 
    (s.[2] = 'l' || s.[2] = 'L') then false
  else
    let rec check i =
      if i >= len then true
      else match s.[i] with
        | 'a'..'z' | 'A'..'Z' | '0'..'9' | '-' | '_' | '.' -> check (i + 1)
        | _ -> false
    in
    check 0

(** Helper to add data-* attributes with validation *)
let set_data_attrs el data =
  List.iter (fun (k, v) -> 
    if is_valid_data_key k then set_attribute el ("data-" ^ k) v
    (* Invalid keys are silently skipped for security *)
  ) data

(** Helper to set int attribute *)
let set_int_attr el name = function
  | Some n -> set_attribute el name (string_of_int n)
  | None -> ()

(** Escape/sanitize attribute names for browser DOM.
    Only allows safe characters: a-z, A-Z, 0-9, hyphen, underscore, period, colon (for namespaced attrs).
    Other characters are replaced with underscore. *)
let escape_attr_name s =
  let buf = Buffer.create (String.length s) in
  String.iter (fun c ->
    match c with
    | 'a'..'z' | 'A'..'Z' | '0'..'9' | '-' | '_' | '.' | ':' -> Buffer.add_char buf c
    | _ -> ()  (* Drop unsafe characters *)
  ) s;
  Buffer.contents buf

(** Helper to set custom attributes *)
let set_attrs el attrs =
  List.iter (fun (k, v) -> 
    set_attribute el (escape_attr_name k) v  (* Escape attribute names *)
  ) attrs

(** {1 Text Content} *)

let text s = Text (create_text_node (document ()) s)
let int n = text (string_of_int n)
let float f = text (string_of_float f)
let empty = Empty

(** Helper for hydration *)
let get_or_create_text_node key initial_value =
  match Hydration.adopt_text_node key with
  | Some txt -> txt
  | None -> create_text_node (document ()) initial_value

let reactive_text signal =
  let key = Hydration.next_hydration_key () in
  let initial = string_of_int (Reactive_core.get_signal signal) in
  let txt = get_or_create_text_node key initial in
  Reactive_core.create_effect (fun () ->
    text_set_data txt (string_of_int (Reactive_core.get_signal signal))
  );
  Text txt

let reactive_text_of fmt signal =
  let key = Hydration.next_hydration_key () in
  let initial = fmt (Reactive_core.get_signal signal) in
  let txt = get_or_create_text_node key initial in
  Reactive_core.create_effect (fun () ->
    text_set_data txt (fmt (Reactive_core.get_signal signal))
  );
  Text txt

let reactive_text_string signal =
  let key = Hydration.next_hydration_key () in
  let initial = Reactive_core.get_signal signal in
  let txt = get_or_create_text_node key initial in
  Reactive_core.create_effect (fun () ->
    text_set_data txt (Reactive_core.get_signal signal)
  );
  Text txt
  
let signal_text = reactive_text

(** {1 Fragment} *)

(** Create a fragment from a list of nodes.
    Unlike wrapping in a span, this preserves the flat structure. *)
let fragment children =
  let frag = create_document_fragment (document ()) in
  List.iter (append_to_fragment frag) children;
  Fragment frag

(** {1 Element Creation} *)

(** Low-level element creation with event handler support and hydration adoption *)
let make_element tag ?id ?class_ ?style ?onclick ?oninput ?onchange ?onkeydown ?onsubmit children =
  (* Try to adopt existing element during hydration *)
  let el, adopted = match Hydration.adopt_element tag with
    | Some existing -> (existing, true)
    | None -> (create_element (document ()) tag, false)
  in
  (* Set attributes (even on adopted elements to ensure consistency) *)
  set_opt_attr el "id" id;
  set_opt_attr el "class" class_;
  set_opt_attr el "style" style;
  (* Attach event handlers *)
  (match onclick with Some h -> add_event_listener el "click" h | None -> ());
  (match oninput with Some h -> add_event_listener el "input" h | None -> ());
  (match onchange with Some h -> add_event_listener el "change" h | None -> ());
  (match onkeydown with Some h -> add_event_listener el "keydown" h | None -> ());
  (match onsubmit with Some h -> add_event_listener el "submit" h | None -> ());
  (* Process children with hydration cursor *)
  Hydration.enter_children el;
  if not adopted then
    (* Only append children to non-adopted elements *)
    List.iter (append_to_element el) children
  else
    (* For adopted elements, still handle text placeholders created in the client. *)
    List.iter (fun child ->
      match child with
      | Text txt ->
        let node = Dom.node_of_text txt in
        if Dom.node_parent_node node = None && Dom.text_data txt = "" then
          Dom.append_child el node
      | Empty -> ()
      | Element _ | Fragment _ ->
        (* Child elements will adopt themselves via recursive make_element calls *)
        ()
    ) children;
  Hydration.exit_children ();
  Element el

(** Helper to create element and set extra attributes *)
let make_element_with_attrs tag ?id ?class_ ?style ?onclick ?oninput ?onchange ?onkeydown ?onsubmit ?(attrs=[]) extra_attrs children =
  let el_node = make_element tag ?id ?class_ ?style ?onclick ?oninput ?onchange ?onkeydown ?onsubmit children in
  match el_node with
  | Element el ->
      extra_attrs el;
      set_attrs el attrs;
      Element el
  | _ -> el_node

(** {1 Document Structure} *)

let div ?id ?class_ ?style ?role ?aria_label ?aria_hidden ?tabindex ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "div" ?id ?class_ ?style ?onclick ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_opt_attr el "aria-label" aria_label;
    (match aria_hidden with Some b -> set_attribute el "aria-hidden" (string_of_bool b) | None -> ());
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children

let span ?id ?class_ ?style ?role ?aria_label ?aria_hidden ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "span" ?id ?class_ ?style ?onclick ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_opt_attr el "aria-label" aria_label;
    (match aria_hidden with Some b -> set_attribute el "aria-hidden" (string_of_bool b) | None -> ());
    set_data_attrs el data
  ) children

let p ?id ?class_ ?role ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "p" ?id ?class_ ?onclick ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_data_attrs el data
  ) children

let pre ?id ?class_ ?(attrs=[]) ~children () =
  make_element_with_attrs "pre" ?id ?class_ ~attrs (fun _ -> ()) children

let code ?id ?class_ ?(attrs=[]) ~children () =
  make_element_with_attrs "code" ?id ?class_ ~attrs (fun _ -> ()) children

(** {1 Headings} *)

let h1 ?id ?class_ ?tabindex ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "h1" ?id ?class_ ?onclick ~attrs (fun el ->
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children
let h2 ?id ?class_ ?tabindex ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "h2" ?id ?class_ ?onclick ~attrs (fun el ->
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children
let h3 ?id ?class_ ?tabindex ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "h3" ?id ?class_ ?onclick ~attrs (fun el ->
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children
let h4 ?id ?class_ ?tabindex ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "h4" ?id ?class_ ?onclick ~attrs (fun el ->
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children
let h5 ?id ?class_ ?tabindex ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "h5" ?id ?class_ ?onclick ~attrs (fun el ->
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children
let h6 ?id ?class_ ?tabindex ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "h6" ?id ?class_ ?onclick ~attrs (fun el ->
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children

(** {1 Sectioning} *)

let header ?id ?class_ ?role ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "header" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_data_attrs el data
  ) children
let footer ?id ?class_ ?role ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "footer" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_data_attrs el data
  ) children
let main ?id ?class_ ?role ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "main" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_data_attrs el data
  ) children
let nav ?id ?class_ ?role ?aria_label ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "nav" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_opt_attr el "aria-label" aria_label;
    set_data_attrs el data
  ) children
let section ?id ?class_ ?role ?aria_label ?aria_labelledby ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "section" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_opt_attr el "aria-label" aria_label;
    set_opt_attr el "aria-labelledby" aria_labelledby;
    set_data_attrs el data
  ) children
let article ?id ?class_ ?role ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "article" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_data_attrs el data
  ) children
let aside ?id ?class_ ?role ?aria_label ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "aside" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_opt_attr el "aria-label" aria_label;
    set_data_attrs el data
  ) children

(** {1 Inline Elements} *)

let a ?id ?class_ ?href ?target ?rel ?download ?hreflang ?tabindex ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "a" ?id ?class_ ?onclick ~attrs (fun el ->
    set_opt_attr el "href" href;
    set_opt_attr el "target" target;
    set_opt_attr el "rel" rel;
    set_opt_attr el "download" download;
    set_opt_attr el "hreflang" hreflang;
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children

let strong ?id ?class_ ?(attrs=[]) ~children () =
  make_element_with_attrs "strong" ?id ?class_ ~attrs (fun _ -> ()) children

let em ?id ?class_ ?(attrs=[]) ~children () =
  make_element_with_attrs "em" ?id ?class_ ~attrs (fun _ -> ()) children

let br ?(attrs=[]) () =
  make_element_with_attrs "br" ~attrs (fun _ -> ()) []

let hr ?class_ ?(attrs=[]) () =
  make_element_with_attrs "hr" ?class_ ~attrs (fun _ -> ()) []

(** {1 Lists} *)

let ul ?id ?class_ ?role ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "ul" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_data_attrs el data
  ) children

let ol ?id ?class_ ?start ?role ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "ol" ?id ?class_ ~attrs (fun el ->
    (match start with Some n -> set_attribute el "start" (string_of_int n) | None -> ());
    set_opt_attr el "role" role;
    set_data_attrs el data
  ) children

let li ?id ?class_ ?role ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "li" ?id ?class_ ?onclick ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_data_attrs el data
  ) children

(** {1 Tables} *)

let table ?id ?class_ ?(attrs=[]) ~children () =
  make_element_with_attrs "table" ?id ?class_ ~attrs (fun _ -> ()) children

let thead ?(attrs=[]) ~children () =
  make_element_with_attrs "thead" ~attrs (fun _ -> ()) children

let tbody ?(attrs=[]) ~children () =
  make_element_with_attrs "tbody" ~attrs (fun _ -> ()) children

let tfoot ?(attrs=[]) ~children () =
  make_element_with_attrs "tfoot" ~attrs (fun _ -> ()) children

let tr ?class_ ?(attrs=[]) ~children () =
  make_element_with_attrs "tr" ?class_ ~attrs (fun _ -> ()) children

let th ?class_ ?scope ?colspan ?rowspan ?(attrs=[]) ~children () =
  make_element_with_attrs "th" ?class_ ~attrs (fun el ->
    set_opt_attr el "scope" scope;
    (match colspan with Some n -> set_attribute el "colspan" (string_of_int n) | None -> ());
    (match rowspan with Some n -> set_attribute el "rowspan" (string_of_int n) | None -> ())
  ) children

let td ?class_ ?colspan ?rowspan ?(attrs=[]) ~children () =
  make_element_with_attrs "td" ?class_ ~attrs (fun el ->
    (match colspan with Some n -> set_attribute el "colspan" (string_of_int n) | None -> ());
    (match rowspan with Some n -> set_attribute el "rowspan" (string_of_int n) | None -> ())
  ) children

(** {1 Forms} *)

let form ?id ?class_ ?action ?method_ ?enctype ?onsubmit ?(attrs=[]) ~children () =
  make_element_with_attrs "form" ?id ?class_ ?onsubmit ~attrs (fun el ->
    set_opt_attr el "action" action;
    set_opt_attr el "method" method_;
    set_opt_attr el "enctype" enctype
  ) children

let input ?id ?class_ ?type_ ?name ?value ?placeholder ?accept ?min ?max ?step
    ?(required=false) ?(disabled=false) ?(checked=false) ?(autofocus=false) ?(readonly=false)
    ?tabindex ?oninput ?onchange ?onkeydown ?(data=[]) ?(attrs=[]) ?children:_children () =
  make_element_with_attrs "input" ?id ?class_ ?oninput ?onchange ?onkeydown ~attrs (fun el ->
    set_opt_attr el "type" type_;
    set_opt_attr el "name" name;
    set_opt_attr el "value" value;
    set_opt_attr el "placeholder" placeholder;
    set_opt_attr el "accept" accept;
    set_opt_attr el "min" min;
    set_opt_attr el "max" max;
    set_opt_attr el "step" step;
    set_bool_attr el "required" required;
    set_bool_attr el "disabled" disabled;
    set_bool_attr el "autofocus" autofocus;
    set_bool_attr el "readonly" readonly;
    set_int_attr el "tabindex" tabindex;
    if checked then element_set_checked el true;
    set_data_attrs el data
  ) []

let textarea ?id ?class_ ?name ?placeholder ?rows ?cols 
    ?(required=false) ?(disabled=false) ?(autofocus=false) ?(readonly=false)
    ?tabindex ?oninput ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "textarea" ?id ?class_ ?oninput ~attrs (fun el ->
    set_opt_attr el "name" name;
    set_opt_attr el "placeholder" placeholder;
    (match rows with Some n -> set_attribute el "rows" (string_of_int n) | None -> ());
    (match cols with Some n -> set_attribute el "cols" (string_of_int n) | None -> ());
    set_bool_attr el "required" required;
    set_bool_attr el "disabled" disabled;
    set_bool_attr el "autofocus" autofocus;
    set_bool_attr el "readonly" readonly;
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children

let select ?id ?class_ ?name ?(required=false) ?(disabled=false) ?(multiple=false) 
    ?(autofocus=false) ?tabindex ?onchange ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "select" ?id ?class_ ?onchange ~attrs (fun el ->
    set_opt_attr el "name" name;
    set_bool_attr el "required" required;
    set_bool_attr el "disabled" disabled;
    set_bool_attr el "multiple" multiple;
    set_bool_attr el "autofocus" autofocus;
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children

let option ?value ?(selected=false) ?(disabled=false) ?(attrs=[]) ~children () =
  make_element_with_attrs "option" ~attrs (fun el ->
    set_opt_attr el "value" value;
    set_bool_attr el "selected" selected;
    set_bool_attr el "disabled" disabled
  ) children

let label ?id ?class_ ?for_ ?(attrs=[]) ~children () =
  make_element_with_attrs "label" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "for" for_
  ) children

let button ?id ?class_ ?type_ ?(disabled=false) ?tabindex ?aria_label ?aria_expanded ?aria_controls ?aria_haspopup ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "button" ?id ?class_ ?onclick ~attrs (fun el ->
    set_opt_attr el "type" type_;
    set_bool_attr el "disabled" disabled;
    set_int_attr el "tabindex" tabindex;
    set_opt_attr el "aria-label" aria_label;
    (match aria_expanded with Some b -> set_attribute el "aria-expanded" (string_of_bool b) | None -> ());
    set_opt_attr el "aria-controls" aria_controls;
    (match aria_haspopup with Some b -> set_attribute el "aria-haspopup" (string_of_bool b) | None -> ());
    set_data_attrs el data
  ) children

(** {1 Media} *)

let img ?id ?class_ ?src ?alt ?width ?height ?loading ?srcset ?sizes ?(data=[]) ?(attrs=[]) () =
  make_element_with_attrs "img" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "src" src;
    set_opt_attr el "alt" alt;
    (match width with Some n -> set_attribute el "width" (string_of_int n) | None -> ());
    (match height with Some n -> set_attribute el "height" (string_of_int n) | None -> ());
    set_opt_attr el "loading" loading;
    set_opt_attr el "srcset" srcset;
    set_opt_attr el "sizes" sizes;
    set_data_attrs el data
  ) []

(** {1 Portal} *)

(** {1 Portal} *)

(** Internal reference to document.body for portal mounting *)
let document_body : element option ref = ref None

let get_document_body () =
  match !document_body with
  | Some body -> body
  | None ->
    let body = Option.get (get_element_by_id (document ()) "body") in
    document_body := Some body;
    body

(** Create a portal that mounts children into a different DOM node.
    - target: DOM element to mount into (None = document.body)
    - is_svg: Use <g> wrapper instead of <div> for SVG context
    - children: Content to render in the portal *)
let portal ?target ?(is_svg=false) ~(children : node) () : node =
  let _placeholder = create_comment (document ()) "portal" in
  
  let mounted_node : Dom.node option ref = ref None in
  
  let cleanup () =
    match !mounted_node with
    | Some node -> remove_node node
    | None -> ()
  in
  
  Reactive_core.create_effect (fun () ->
    let target = match target with
      | Some el -> el
      | None -> get_document_body ()
    in
    
    let children_node = to_dom_node children in
    
    let content = if is_svg then
      children_node
    else if get_tag_name target = "HEAD" then
      children_node
    else
      let wrapper = create_element (document ()) "div" in
      set_attribute wrapper "data-solid-ml-portal" "";
      append_child wrapper children_node;
      node_of_element wrapper
    in
    
    append_child target content;
    mounted_node := Some content;
    
    Reactive_core.on_cleanup cleanup
  );
  
  Text (create_text_node (document ()) "")

(** {1 SVG Elements} *)

module Svg = struct
  let svg ?xmlns:_xmlns ?id ?class_ ?style ?viewBox ?width ?height ?fill ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns (document ()) svg_namespace "svg" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "viewBox" viewBox;
    set_opt_attr el "width" width;
    set_opt_attr el "height" height;
    set_opt_attr el "fill" fill;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let g ?id ?class_ ?style ?transform ?fill ?stroke ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns (document ()) svg_namespace "g" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "transform" transform;
    set_opt_attr el "fill" fill;
    set_opt_attr el "stroke" stroke;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let circle ?id ?class_ ?style ?cx ?cy ?r ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns (document ()) svg_namespace "circle" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "cx" cx;
    set_opt_attr el "cy" cy;
    set_opt_attr el "r" r;
    set_opt_attr el "fill" fill;
    set_opt_attr el "stroke" stroke;
    set_opt_attr el "stroke-width" stroke_width;
    set_opt_attr el "stroke-linecap" stroke_linecap;
    set_opt_attr el "stroke-linejoin" stroke_linejoin;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let ellipse ?id ?class_ ?style ?cx ?cy ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns (document ()) svg_namespace "ellipse" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "cx" cx;
    set_opt_attr el "cy" cy;
    set_opt_attr el "rx" rx;
    set_opt_attr el "ry" ry;
    set_opt_attr el "fill" fill;
    set_opt_attr el "stroke" stroke;
    set_opt_attr el "stroke-width" stroke_width;
    set_opt_attr el "stroke-linecap" stroke_linecap;
    set_opt_attr el "stroke-linejoin" stroke_linejoin;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let rect ?id ?class_ ?style ?x ?y ?width ?height ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns (document ()) svg_namespace "rect" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "x" x;
    set_opt_attr el "y" y;
    set_opt_attr el "width" width;
    set_opt_attr el "height" height;
    set_opt_attr el "rx" rx;
    set_opt_attr el "ry" ry;
    set_opt_attr el "fill" fill;
    set_opt_attr el "stroke" stroke;
    set_opt_attr el "stroke-width" stroke_width;
    set_opt_attr el "stroke-linecap" stroke_linecap;
    set_opt_attr el "stroke-linejoin" stroke_linejoin;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let line ?id ?class_ ?style ?x1 ?y1 ?x2 ?y2 ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns (document ()) svg_namespace "line" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "x1" x1;
    set_opt_attr el "y1" y1;
    set_opt_attr el "x2" x2;
    set_opt_attr el "y2" y2;
    set_opt_attr el "stroke" stroke;
    set_opt_attr el "stroke-width" stroke_width;
    set_opt_attr el "stroke-linecap" stroke_linecap;
    set_opt_attr el "stroke-linejoin" stroke_linejoin;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let polyline ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns (document ()) svg_namespace "polyline" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "points" points;
    set_opt_attr el "fill" fill;
    set_opt_attr el "stroke" stroke;
    set_opt_attr el "stroke-width" stroke_width;
    set_opt_attr el "stroke-linecap" stroke_linecap;
    set_opt_attr el "stroke-linejoin" stroke_linejoin;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let polygon ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns (document ()) svg_namespace "polygon" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "points" points;
    set_opt_attr el "fill" fill;
    set_opt_attr el "stroke" stroke;
    set_opt_attr el "stroke-width" stroke_width;
    set_opt_attr el "stroke-linecap" stroke_linecap;
    set_opt_attr el "stroke-linejoin" stroke_linejoin;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let path ?id ?class_ ?style ?d ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?fill_rule ?clip_rule ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns (document ()) svg_namespace "path" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "d" d;
    set_opt_attr el "fill" fill;
    set_opt_attr el "stroke" stroke;
    set_opt_attr el "stroke-width" stroke_width;
    set_opt_attr el "stroke-linecap" stroke_linecap;
    set_opt_attr el "stroke-linejoin" stroke_linejoin;
    set_opt_attr el "fill-rule" fill_rule;
    set_opt_attr el "clip-rule" clip_rule;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let text_ ?id ?class_ ?style ?x ?y ?dx ?dy ?text_anchor ?font_size ?font_family ?fill ?stroke ?stroke_width ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns (document ()) svg_namespace "text" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "x" x;
    set_opt_attr el "y" y;
    set_opt_attr el "dx" dx;
    set_opt_attr el "dy" dy;
    set_opt_attr el "text-anchor" text_anchor;
    set_opt_attr el "font-size" font_size;
    set_opt_attr el "font-family" font_family;
    set_opt_attr el "fill" fill;
    set_opt_attr el "stroke" stroke;
    set_opt_attr el "stroke-width" stroke_width;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let tspan ?id ?class_ ?x ?y ?dx ?dy ?fill ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns (document ()) svg_namespace "tspan" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "x" x;
    set_opt_attr el "y" y;
    set_opt_attr el "dx" dx;
    set_opt_attr el "dy" dy;
    set_opt_attr el "fill" fill;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let defs ?id ?(attrs=[]) ~children () =
    let el = create_element_ns (document ()) svg_namespace "defs" in
    set_opt_attr el "id" id;
    set_attrs el attrs;
    List.iter (append_to_element el) children;
    Element el

  let use ?id ?class_ ?href ?x ?y ?width ?height ?onclick ?(attrs=[]) () =
    let el = create_element_ns (document ()) svg_namespace "use" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "href" href;
    set_opt_attr el "x" x;
    set_opt_attr el "y" y;
    set_opt_attr el "width" width;
    set_opt_attr el "height" height;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    Element el

  let symbol ?id ?viewBox ?(attrs=[]) ~children () =
    let el = create_element_ns (document ()) svg_namespace "symbol" in
    set_opt_attr el "id" id;
    set_opt_attr el "viewBox" viewBox;
    set_attrs el attrs;
    List.iter (append_to_element el) children;
    Element el

  let clipPath ?id ?(attrs=[]) ~children () =
    let el = create_element_ns (document ()) svg_namespace "clipPath" in
    set_opt_attr el "id" id;
    set_attrs el attrs;
    List.iter (append_to_element el) children;
    Element el

  let mask ?id ?(attrs=[]) ~children () =
    let el = create_element_ns (document ()) svg_namespace "mask" in
    set_opt_attr el "id" id;
    set_attrs el attrs;
    List.iter (append_to_element el) children;
    Element el

  let linearGradient ?id ?x1 ?y1 ?x2 ?y2 ?gradientUnits ?gradientTransform ?(attrs=[]) ~children () =
    let el = create_element_ns (document ()) svg_namespace "linearGradient" in
    set_opt_attr el "id" id;
    set_opt_attr el "x1" x1;
    set_opt_attr el "y1" y1;
    set_opt_attr el "x2" x2;
    set_opt_attr el "y2" y2;
    set_opt_attr el "gradientUnits" gradientUnits;
    set_opt_attr el "gradientTransform" gradientTransform;
    set_attrs el attrs;
    List.iter (append_to_element el) children;
    Element el

  let radialGradient ?id ?cx ?cy ?r ?fx ?fy ?gradientUnits ?gradientTransform ?(attrs=[]) ~children () =
    let el = create_element_ns (document ()) svg_namespace "radialGradient" in
    set_opt_attr el "id" id;
    set_opt_attr el "cx" cx;
    set_opt_attr el "cy" cy;
    set_opt_attr el "r" r;
    set_opt_attr el "fx" fx;
    set_opt_attr el "fy" fy;
    set_opt_attr el "gradientUnits" gradientUnits;
    set_opt_attr el "gradientTransform" gradientTransform;
    set_attrs el attrs;
    List.iter (append_to_element el) children;
    Element el

  let stop ?offset ?stop_color ?stop_opacity ?(attrs=[]) () =
    let el = create_element_ns (document ()) svg_namespace "stop" in
    set_opt_attr el "offset" offset;
    set_opt_attr el "stop-color" stop_color;
    set_opt_attr el "stop-opacity" stop_opacity;
    set_attrs el attrs;
    Element el

  let image ?id ?class_ ?href ?x ?y ?width ?height ?preserveAspectRatio ?(attrs=[]) () =
    let el = create_element_ns (document ()) svg_namespace "image" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "href" href;
    set_opt_attr el "x" x;
    set_opt_attr el "y" y;
    set_opt_attr el "width" width;
    set_opt_attr el "height" height;
    set_opt_attr el "preserveAspectRatio" preserveAspectRatio;
    set_attrs el attrs;
    Element el

  let foreignObject ?id ?class_ ?x ?y ?width ?height ?(attrs=[]) ~children () =
    let el = create_element_ns (document ()) svg_namespace "foreignObject" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "x" x;
    set_opt_attr el "y" y;
    set_opt_attr el "width" width;
    set_opt_attr el "height" height;
    set_attrs el attrs;
    List.iter (append_to_element el) children;
    Element el
end

let svg ?xmlns ?id ?class_ ?style ?viewBox ?width ?height ?fill ?onclick ?attrs ~children () =
  Svg.svg ?xmlns ?id ?class_ ?style ?viewBox ?width ?height ?fill ?onclick ?attrs ~children ()

let g ?id ?class_ ?style ?transform ?fill ?stroke ?onclick ?attrs ~children () =
  Svg.g ?id ?class_ ?style ?transform ?fill ?stroke ?onclick ?attrs ~children ()

let circle ?id ?class_ ?style ?cx ?cy ?r ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children () =
  Svg.circle ?id ?class_ ?style ?cx ?cy ?r ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children ()

let ellipse ?id ?class_ ?style ?cx ?cy ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children () =
  Svg.ellipse ?id ?class_ ?style ?cx ?cy ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children ()

let rect ?id ?class_ ?style ?x ?y ?width ?height ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children () =
  Svg.rect ?id ?class_ ?style ?x ?y ?width ?height ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children ()

let line ?id ?class_ ?style ?x1 ?y1 ?x2 ?y2 ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children () =
  Svg.line ?id ?class_ ?style ?x1 ?y1 ?x2 ?y2 ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children ()

let polyline ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children () =
  Svg.polyline ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children ()

let polygon ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children () =
  Svg.polygon ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children ()

let path ?id ?class_ ?style ?d ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?fill_rule ?clip_rule ?onclick ?attrs ~children () =
  Svg.path ?id ?class_ ?style ?d ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?fill_rule ?clip_rule ?onclick ?attrs ~children ()

let text_ ?id ?class_ ?style ?x ?y ?dx ?dy ?text_anchor ?font_size ?font_family ?fill ?stroke ?stroke_width ?onclick ?attrs ~children () =
  Svg.text_ ?id ?class_ ?style ?x ?y ?dx ?dy ?text_anchor ?font_size ?font_family ?fill ?stroke ?stroke_width ?onclick ?attrs ~children ()

(** {1 Node Access} *)

(** Get the underlying DOM element (for direct manipulation) *)
let get_element = function
  | Element el -> Some el
  | Text _ | Fragment _ | Empty -> None

(** Get the underlying DOM text node *)
let get_text_node = function
  | Text txt -> Some txt
  | Element _ | Fragment _ | Empty -> None
