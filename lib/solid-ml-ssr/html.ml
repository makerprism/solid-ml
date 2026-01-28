(** HTML element functions for server-side rendering. *)

(** Event type stub for unified interface.
    On SSR, events are never instantiated - handlers are ignored. *)
type event = unit

type element = unit

type 'a signal = 'a Solid_ml.Signal.t

(** Hydration key counter for marking reactive elements *)
let hydration_key = ref 0

let svg_namespace = "http://www.w3.org/2000/svg"

let next_hydration_key () =
  let key = !hydration_key in
  incr hydration_key;
  key

let reset_hydration_keys () =
  hydration_key := 0

(** HTML node type *)
type node =
  | Text of string
  | Raw of string
  | Element of {
      tag : string;
      attrs : (string * string) list;
      children : node list;
      self_closing : bool;
    }
  | Fragment of node list
  | ReactiveText of { key : int; value : string }

(** Escape HTML special characters in attribute values and text *)
let escape_html s =
  let buf = Buffer.create (String.length s) in
  String.iter (fun c ->
    match c with
    | '&' -> Buffer.add_string buf "&amp;"
    | '<' -> Buffer.add_string buf "&lt;"
    | '>' -> Buffer.add_string buf "&gt;"
    | '"' -> Buffer.add_string buf "&quot;"
    | '\'' -> Buffer.add_string buf "&#x27;"
    | _ -> Buffer.add_char buf c
  ) s;
  Buffer.contents buf

type template_element = {
  inst : template_instance;
  path : int list;
}

and template = {
  segments : string array;
  slot_kinds : Solid_ml_template_runtime.slot_kind array;
}

and template_instance = {
  template : template;
  values : string array;
  (* Escaped attribute values stored by element path. *)
  mutable attrs_by_path : (int list * (string * string) list) list;
}

module Internal_template : Solid_ml_template_runtime.TEMPLATE
  with type node := node
   and type event := event
   and type element = template_element = struct
  type nonrec template = template
  type nonrec instance = template_instance

  type text_slot = {
    inst : instance;
    id : int;
  }

  type nodes_slot = {
    inst : instance;
    id : int;
  }

  type event_options = {
    capture : bool;
    passive : bool;
    once : bool;
  }

  type element = template_element

  let compile ~segments ~slot_kinds =
    if Array.length segments <> Array.length slot_kinds + 1 then
      invalid_arg "Solid_ml_ssr.Html.Internal_template.compile: segments length must be slot_kinds length + 1";
    { segments; slot_kinds }

  let instantiate template =
    let values = Array.make (Array.length template.slot_kinds) "" in
    { template; values; attrs_by_path = [] }

  let bind_text inst ~id ~path:_ : text_slot =
    if id < 0 || id >= Array.length inst.values then
      invalid_arg "Solid_ml_ssr.Html.Internal_template.bind_text: id out of bounds";
    { inst; id }

  let set_text (slot : text_slot) value =
    slot.inst.values.(slot.id) <- value

  let bind_nodes inst ~id ~path:_ : nodes_slot =
    if id < 0 || id >= Array.length inst.values then
      invalid_arg "Solid_ml_ssr.Html.Internal_template.bind_nodes: id out of bounds";
    { inst; id }

  let rec render_node_for_slot (n : node) : string =
    match n with
    | Text s -> escape_html s
    | Raw s -> s
    | ReactiveText { key; value } ->
      Printf.sprintf "<!--hk:%d-->%s<!--/hk-->" key (escape_html value)
    | Fragment children -> String.concat "" (List.map render_node_for_slot children)
    | Element { tag; attrs; children; self_closing } ->
      let attrs_str =
        if attrs = [] then ""
        else
          " "
          ^ String.concat " "
              (List.map
                 (fun (k, v) ->
                    let safe_key =
                      let buf = Buffer.create (String.length k) in
                      String.iter
                        (fun c ->
                          match c with
                          | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' | '_' | '.' | ':' ->
                            Buffer.add_char buf c
                          | _ -> Buffer.add_char buf '_')
                        k;
                      Buffer.contents buf
                    in
                    if v = "" then safe_key
                    else Printf.sprintf "%s=\"%s\"" safe_key (escape_html v))
                 attrs)
      in
      if self_closing then Printf.sprintf "<%s%s />" tag attrs_str
      else
        let children_str =
          String.concat "" (List.map render_node_for_slot children)
        in
        Printf.sprintf "<%s%s>%s</%s>" tag attrs_str children_str tag

  let set_nodes (slot : nodes_slot) value =
    slot.inst.values.(slot.id) <- render_node_for_slot value

  let bind_element inst ~id:_ ~path = { inst; path = Array.to_list path }

  let escape_attr_name_local s =
    let buf = Buffer.create (String.length s) in
    String.iter
      (fun c ->
        match c with
        | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' | '_' | '.' | ':' ->
          Buffer.add_char buf c
        | _ -> Buffer.add_char buf '_')
      s;
    Buffer.contents buf

  let path_equal (a : int list) (b : int list) : bool =
    List.length a = List.length b && List.for_all2 Int.equal a b

  let update_attrs_by_path (inst : instance) ~(path : int list) ~(name : string)
      (value_opt : string option) : unit =
    let rec update = function
      | [] ->
        (match value_opt with
         | None -> []
         | Some v -> [ (path, [ (name, v) ]) ])
      | (p, attrs) :: rest when path_equal p path ->
        let attrs = List.filter (fun (k, _) -> k <> name) attrs in
        let attrs =
          match value_opt with
          | None -> attrs
          | Some v -> attrs @ [ (name, v) ]
        in
        if attrs = [] then rest else (p, attrs) :: rest
      | x :: rest -> x :: update rest
    in
    inst.attrs_by_path <- update inst.attrs_by_path

  let set_attr (el : element) ~name (value_opt : string option) =
    let name = escape_attr_name_local name in
    let value_opt = Option.map escape_html value_opt in
    update_attrs_by_path el.inst ~path:el.path ~name value_opt

  let run_updates fn =
    match Solid_ml.Reactive.get_runtime_opt () with
    | None -> fn ()
    | Some rt ->
      if rt.Solid_ml_internal.Types.in_update then (
        rt.in_update <- false;
        let res = Solid_ml.Reactive.run_updates fn false in
        rt.in_update <- true;
        res)
      else
        Solid_ml.Reactive.run_updates fn false

  let set_value (el : element) (value : string) =
    set_attr el ~name:"value" (Some value)

  let get_value (el : element) : string =
    let rec find = function
      | [] -> ""
      | (p, attrs) :: _rest when path_equal p el.path ->
        (match List.find_opt (fun (k, _) -> String.equal k "value") attrs with
         | Some (_, v) -> v
         | None -> "")
      | _ :: rest -> find rest
    in
    find el.inst.attrs_by_path

  let set_checked (el : element) (value : bool) =
    if value then set_attr el ~name:"checked" (Some "") else set_attr el ~name:"checked" None

  let get_checked (_el : element) : bool =
    false

  let set_selected_values (_el : element) (_values : string array) =
    ()

  let get_selected_values (_el : element) : string array =
    [||]

  let observe_children (_el : element) (_handler : unit -> unit) : unit -> unit =
    fun () -> ()

  let wrap_handler ?prevent_default:_ ?stop_propagation:_ handler =
    handler

  let on_ (_el : element) ~event:_ ?options:_ _ = ()
  let off_ (_el : element) ~event:_ ?options:_ _ = ()

  let set_nodes_keyed (slot : nodes_slot) ~key ~render items =
    let children, disposers =
      List.split (List.map render items)
    in
    (* In SSR, we render the list immediately. Disposers are invoked eagerly since
       there is no persistent DOM to keep alive. *)
    List.iter (fun d -> d ()) disposers;

    (* Match the browser CSR structure and support hydration adoption:
       each keyed item is wrapped in a start marker carrying the key and a stop
       marker.

       We hex-encode the key so it is safe to embed in comment text. *)
    let encode_key (s : string) : string =
      let buf = Buffer.create (String.length s * 2) in
      String.iter (fun c -> Buffer.add_string buf (Printf.sprintf "%02x" (Char.code c))) s;
      Buffer.contents buf
    in

    let wrap_keyed (k : string) (n : node) : node =
      let k_enc = encode_key k in
      Fragment [ Raw ("<!--k:" ^ k_enc ^ "-->"); n; Raw "<!--/k-->" ]
    in

    let keyed_children =
      List.map2 (fun item child -> wrap_keyed (key item) child) items children
    in
    set_nodes slot (Fragment keyed_children)

  let set_nodes_indexed (slot : nodes_slot) ~render items =
    let children, disposers =
      List.split (List.mapi (fun idx item -> render idx item) items)
    in
    List.iter (fun d -> d ()) disposers;

    let encode_key (s : string) : string =
      let buf = Buffer.create (String.length s * 2) in
      String.iter (fun c -> Buffer.add_string buf (Printf.sprintf "%02x" (Char.code c))) s;
      Buffer.contents buf
    in
    let wrap_keyed (k : string) (n : node) : node =
      let k_enc = encode_key k in
      Fragment [ Raw ("<!--k:" ^ k_enc ^ "-->"); n; Raw "<!--/k-->" ]
    in
    let keyed_children =
      List.mapi (fun idx child -> wrap_keyed (string_of_int idx) child) children
    in
    set_nodes slot (Fragment keyed_children)

  let set_nodes_indexed_accessors slot ~items ~render =
    let items_arr = Array.of_list (items ()) in
    let indices = List.init (Array.length items_arr) (fun i -> i) in
    let render_idx idx =
      let item = items_arr.(idx) in
      run_updates (fun () -> render ~index:(fun () -> idx) ~item:(fun () -> item))
    in
    set_nodes_keyed slot ~key:string_of_int ~render:render_idx indices


  type frame = {
    path : int list;
    mutable next_child : int;
  }

  let attrs_string (attrs : (string * string) list) : string =
    if attrs = [] then ""
    else
      " "
      ^ String.concat " "
          (List.map (fun (k, v) -> Printf.sprintf "%s=\"%s\"" k v) attrs)

  let build_rendered_and_open_tag_ends (inst : instance) : string * (int list * int) list =
    let segments = inst.template.segments in
    let slot_kinds = inst.template.slot_kinds in
    let buf = Buffer.create 256 in
    let open_tag_ends_rev = ref [] in

    let stack : frame list ref = ref [] in
    let text_pending = ref false in

    let flush_text_pending () =
      if !text_pending && !stack <> [] then (
        let top = List.hd !stack in
        top.next_child <- top.next_child + 1);
      text_pending := false
    in

    let is_name_char = function
      | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' | '_' | ':' -> true
      | _ -> false
    in

    let rec find_tag_close (s : string) i quote =
      if i >= String.length s then None
      else
        let c = s.[i] in
        match quote with
        | Some q when c = q -> find_tag_close s (i + 1) None
        | Some _ -> find_tag_close s (i + 1) quote
        | None ->
          (match c with
           | '"' | '\'' -> find_tag_close s (i + 1) (Some c)
           | '>' -> Some i
           | _ -> find_tag_close s (i + 1) None)
    in

    let rec parse_tag_name (s : string) i =
      if i >= String.length s then i
      else if is_name_char s.[i] then parse_tag_name s (i + 1)
      else i
    in

    let is_self_closing (s : string) close_idx =
      let rec prev_non_ws j =
        if j <= 0 then 0
        else
          match s.[j] with
          | ' ' | '\n' | '\r' | '\t' -> prev_non_ws (j - 1)
          | _ -> j
      in
      let j = prev_non_ws (close_idx - 1) in
      j > 0 && s.[j] = '/'
    in

    let scan_segment (seg : string) : unit =
      let base = Buffer.length buf in
      let len = String.length seg in
      let rec loop i =
        if i >= len then ()
        else if seg.[i] <> '<' then (
          if !stack <> [] then text_pending := true;
          loop (i + 1))
        else (
          flush_text_pending ();
          if i + 1 >= len then loop (i + 1)
          else
            match seg.[i + 1] with
            | '/' ->
              (* End tag. *)
              (match find_tag_close seg (i + 2) None with
               | None -> loop (i + 1)
               | Some close_idx ->
                 (match !stack with
                  | [] -> ()
                  | _ :: rest -> stack := rest);
                 loop (close_idx + 1))
            | '!' ->
              (* Comment/doctype. Comments are real childNodes inside elements,
                 so they must increment the current child index. *)
              (match find_tag_close seg (i + 2) None with
               | None -> loop (i + 1)
               | Some close_idx ->
                 (match !stack with
                  | [] -> ()
                  | top :: _ -> top.next_child <- top.next_child + 1);
                 loop (close_idx + 1))
            | _ ->
              (* Start tag. *)
              let name_start = i + 1 in
              let name_end = parse_tag_name seg name_start in
              if name_end = name_start then (
                if !stack <> [] then text_pending := true;
                loop (i + 1))
              else
                match find_tag_close seg name_end None with
                | None -> loop (i + 1)
                | Some close_idx ->
                  let path =
                    match !stack with
                    | [] -> []
                    | top :: _ ->
                      let idx = top.next_child in
                      top.next_child <- top.next_child + 1;
                      top.path @ [ idx ]
                  in
                  open_tag_ends_rev := (path, base + close_idx) :: !open_tag_ends_rev;
                  if not (is_self_closing seg close_idx) then
                    stack := { path; next_child = 0 } :: !stack;
                  loop (close_idx + 1))
      in
      loop 0;
      Buffer.add_string buf seg
    in

    scan_segment segments.(0);
    for i = 0 to Array.length slot_kinds - 1 do
      flush_text_pending ();
      (* With SolidJS-style paired comment markers around text slots, the SSR HTML
         contains the markers but no dedicated text node for the slot.

         The browser backend inserts a text node between the markers at bind time,
         so for SSR path purposes we should NOT advance [next_child] here. *)

      let raw_value = inst.values.(i) in
      let rendered_value =
        match slot_kinds.(i) with
        | `Nodes | `Nodes_transition -> raw_value
        | `Text | `Attr -> escape_html raw_value
      in
      Buffer.add_string buf rendered_value;
      scan_segment segments.(i + 1)
    done;
    flush_text_pending ();

    (Buffer.contents buf, List.rev !open_tag_ends_rev)

  let render (inst : instance) : string =
    match inst.attrs_by_path with
    | [] ->
      (* Fast path: no element-bound attrs to inject. *)
      let buf = Buffer.create 256 in
      let segments = inst.template.segments in
      let slot_kinds = inst.template.slot_kinds in
      Buffer.add_string buf segments.(0);
      for i = 0 to Array.length slot_kinds - 1 do
        let raw_value = inst.values.(i) in
         (match slot_kinds.(i) with
          | `Nodes | `Nodes_transition -> Buffer.add_string buf raw_value
          | `Attr | `Text -> Buffer.add_string buf (escape_html raw_value));
        Buffer.add_string buf segments.(i + 1)
      done;
      Buffer.contents buf
    | attrs_by_path ->
      let string_of_path (path : int list) : string =
        match path with
        | [] -> "[]"
        | _ -> "[" ^ String.concat ";" (List.map string_of_int path) ^ "]"
      in

      let rendered, open_tag_ends = build_rendered_and_open_tag_ends inst in

      let find_path_end path =
        List.find_map
          (fun (p, idx) -> if path_equal p path then Some idx else None)
          open_tag_ends
      in

      let take_n n xs =
        let rec go acc n = function
          | [] -> List.rev acc
          | _ when n <= 0 -> List.rev acc
          | x :: rest -> go (x :: acc) (n - 1) rest
        in
        go [] n xs
      in

      let available_paths_preview =
        open_tag_ends
        |> List.map fst
        |> List.sort_uniq Stdlib.compare
        |> take_n 12
        |> fun paths -> String.concat ", " (List.map string_of_path paths)
      in

      let injections =
        List.filter_map
          (fun (path, attrs) ->
            match find_path_end path with
            | None ->
              invalid_arg
                (Printf.sprintf
                   "Solid_ml_ssr.Html.Template: path out of bounds for element %s (available paths: %s)"
                   (string_of_path path) available_paths_preview)
            | Some idx ->
              if attrs = [] then None else Some (idx, attrs_string attrs))
          attrs_by_path
      in
      let injections =
        List.sort (fun (a, _) (b, _) -> Int.compare b a) injections
      in
      List.fold_left
        (fun acc (idx, ins) ->
          let before = String.sub acc 0 idx in
          let after = String.sub acc idx (String.length acc - idx) in
          before ^ ins ^ after)
        rendered injections

  let root inst = Raw (render inst)
end

(** Escape/sanitize attribute names.
    Only allows safe characters: a-z, A-Z, 0-9, hyphen, underscore, period, colon (for namespaced attrs).
    Other characters are replaced with underscore. *)
let escape_attr_name s =
  let buf = Buffer.create (String.length s) in
  String.iter (fun c ->
    match c with
    | 'a'..'z' | 'A'..'Z' | '0'..'9' | '-' | '_' | '.' | ':' -> Buffer.add_char buf c
    | _ -> Buffer.add_char buf '_'
  ) s;
  Buffer.contents buf

(** Convert node to HTML string *)
let rec to_string node =
  match node with
  | Text s -> escape_html s
  | Raw s -> s
  | ReactiveText { key; value } ->
    Printf.sprintf "<!--hk:%d-->%s<!--/hk-->" key (escape_html value)
  | Fragment children ->
    String.concat "" (List.map to_string children)
  | Element { tag; attrs; children; self_closing } ->
    let attrs_str =
      if attrs = [] then ""
      else
        " " ^ String.concat " " (List.map (fun (k, v) ->
          let safe_key = escape_attr_name k in
          if v = "" then safe_key  (* Boolean attribute *)
          else Printf.sprintf "%s=\"%s\"" safe_key (escape_html v)
        ) attrs)
    in
    if self_closing then
      Printf.sprintf "<%s%s />" tag attrs_str
    else
      let children_str = String.concat "" (List.map to_string children) in
      Printf.sprintf "<%s%s>%s</%s>" tag attrs_str children_str tag

(** Text content constructors *)
let text s = Text s
let int n = Text (string_of_int n)
let float f = Text (string_of_float f)
let raw s = Raw s

(** Reactive text functions - unified API for SSR/browser *)

let reactive_text signal =
  let key = next_hydration_key () in
  let value = string_of_int (Solid_ml.Signal.peek signal) in
  ReactiveText { key; value }

let reactive_text_of fmt signal =
  let key = next_hydration_key () in
  let value = fmt (Solid_ml.Signal.peek signal) in
  ReactiveText { key; value }

let reactive_text_string signal =
  let key = next_hydration_key () in
  let value = Solid_ml.Signal.peek signal in
  ReactiveText { key; value }

(** Common attributes type *)
type common_attrs = {
  id : string option;
  class_ : string option;
  style : string option;
  title : string option;
  data : (string * string) list;
}

let no_attrs = { id = None; class_ = None; style = None; title = None; data = [] }

(** Helper to add optional attribute to list *)
let add_opt name value attrs =
  match value with Some v -> (name, v) :: attrs | None -> attrs

let add_bool name value attrs =
  if value then (name, "") :: attrs else attrs

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
let add_data data attrs =
  List.fold_left (fun acc (k, v) -> 
    if is_valid_data_key k then ("data-" ^ k, v) :: acc 
    else acc  (* Silently skip invalid keys for security *)
  ) attrs data

(** Helper to add int attribute *)
let add_int name value attrs =
  match value with Some n -> (name, string_of_int n) :: attrs | None -> attrs

(** Helper to add custom attributes *)
let add_attrs custom_attrs attrs =
  List.fold_left (fun acc (k, v) -> 
    let safe_key = escape_attr_name k in
    (safe_key, v) :: acc
  ) attrs custom_attrs

let element tag ?(self_closing=false) attrs children =
  Element { tag; attrs; children; self_closing }

(** Document structure elements *)
let html ?lang ?(attrs=[]) ~children () =
  element "html" (add_opt "lang" lang attrs) children

let head ?(attrs=[]) ~children () =
  element "head" attrs children

let body ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "body" attrs children

let title ?(attrs=[]) ~children () =
  element "title" attrs children

let meta ?charset ?name ?property ?content ?(attrs=[]) () =
  let attrs = [] 
    |> add_opt "charset" charset 
    |> add_opt "name" name 
    |> add_opt "property" property 
    |> add_opt "content" content
    |> add_attrs attrs
  in
  element "meta" ~self_closing:true attrs []

let link ?rel ?href ?hreflang ?type_ ?(attrs=[]) () =
  let attrs = [] 
    |> add_opt "rel" rel 
    |> add_opt "href" href 
    |> add_opt "hreflang" hreflang 
    |> add_opt "type" type_
    |> add_attrs attrs
  in
  element "link" ~self_closing:true attrs []

let script ?src ?type_ ?(defer=false) ?(async=false) ?(attrs=[]) ~children () =
  let attrs = [] 
    |> add_opt "src" src 
    |> add_opt "type" type_
    |> add_bool "defer" defer
    |> add_bool "async" async
    |> add_attrs attrs
  in
  element "script" attrs children

(** Content sectioning *)
let header ?id ?class_ ?role ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_data data
    |> add_attrs attrs
  in
  element "header" attrs children

let footer ?id ?class_ ?role ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_data data
    |> add_attrs attrs
  in
  element "footer" attrs children

let main ?id ?class_ ?role ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_data data
    |> add_attrs attrs
  in
  element "main" attrs children

let nav ?id ?class_ ?role ?aria_label ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_opt "aria-label" aria_label
    |> add_data data
    |> add_attrs attrs
  in
  element "nav" attrs children

let section ?id ?class_ ?role ?aria_label ?aria_labelledby ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_opt "aria-label" aria_label
    |> add_opt "aria-labelledby" aria_labelledby
    |> add_data data
    |> add_attrs attrs
  in
  element "section" attrs children

let article ?id ?class_ ?role ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_data data
    |> add_attrs attrs
  in
  element "article" attrs children

let aside ?id ?class_ ?role ?aria_label ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_opt "aria-label" aria_label
    |> add_data data
    |> add_attrs attrs
  in
  element "aside" attrs children

let figure ?id ?class_ ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_data data
    |> add_attrs attrs
  in
  element "figure" attrs children

let figcaption ?id ?class_ ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_data data
    |> add_attrs attrs
  in
  element "figcaption" attrs children

let address ?id ?class_ ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_data data
    |> add_attrs attrs
  in
  element "address" attrs children

let details ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "details" attrs children

let summary ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "summary" attrs children

(** Text content *)
let div ?id ?class_ ?style ?role ?aria_label ?aria_hidden ?tabindex ?onclick:_ ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "style" style
    |> add_opt "role" role
    |> add_opt "aria-label" aria_label
    |> add_opt "aria-hidden" (Option.map string_of_bool aria_hidden)
    |> add_int "tabindex" tabindex
    |> add_data data
    |> add_attrs attrs
  in
  element "div" attrs children

let p ?id ?class_ ?role ?onclick:_ ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_data data
    |> add_attrs attrs
  in
  element "p" attrs children

let span ?id ?class_ ?style ?role ?aria_label ?aria_hidden ?onclick:_ ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "style" style
    |> add_opt "role" role
    |> add_opt "aria-label" aria_label
    |> add_opt "aria-hidden" (Option.map string_of_bool aria_hidden)
    |> add_data data
    |> add_attrs attrs
  in
  element "span" attrs children

let pre ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "pre" attrs children

let code ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "code" attrs children

let blockquote ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "blockquote" attrs children

(** Headings *)
let h1 ?id ?class_ ?tabindex ?onclick:_ ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_int "tabindex" tabindex
    |> add_data data
    |> add_attrs attrs
  in
  element "h1" attrs children

let h2 ?id ?class_ ?tabindex ?onclick:_ ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_int "tabindex" tabindex
    |> add_data data
    |> add_attrs attrs
  in
  element "h2" attrs children

let h3 ?id ?class_ ?tabindex ?onclick:_ ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_int "tabindex" tabindex
    |> add_data data
    |> add_attrs attrs
  in
  element "h3" attrs children

let h4 ?id ?class_ ?tabindex ?onclick:_ ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_int "tabindex" tabindex
    |> add_data data
    |> add_attrs attrs
  in
  element "h4" attrs children

let h5 ?id ?class_ ?tabindex ?onclick:_ ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_int "tabindex" tabindex
    |> add_data data
    |> add_attrs attrs
  in
  element "h5" attrs children

let h6 ?id ?class_ ?tabindex ?onclick:_ ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_int "tabindex" tabindex
    |> add_data data
    |> add_attrs attrs
  in
  element "h6" attrs children

(** Inline text *)
let a ?id ?class_ ?href ?target ?rel ?download ?hreflang ?tabindex ?onclick:_ ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "href" href
    |> add_opt "target" target
    |> add_opt "rel" rel
    |> add_opt "download" download
    |> add_opt "hreflang" hreflang
    |> add_int "tabindex" tabindex
    |> add_data data
    |> add_attrs attrs
  in
  element "a" attrs children

let strong ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "strong" attrs children

let em ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "em" attrs children

let b ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "b" attrs children

let i ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "i" attrs children

let u ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "u" attrs children

let s ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "s" attrs children

let small ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "small" attrs children

let mark ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "mark" attrs children

let sup ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "sup" attrs children

let sub ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "sub" attrs children

let cite ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "cite" attrs children

let q ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "q" attrs children

let abbr ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "abbr" attrs children

let data ?id ?class_ ?value ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "value" value
    |> add_attrs attrs
  in
  element "data" attrs children

let time ?id ?class_ ?datetime ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "datetime" datetime
    |> add_attrs attrs
  in
  element "time" attrs children

let kbd ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "kbd" attrs children

let samp ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "samp" attrs children

let var ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "var" attrs children

let del ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "del" attrs children

let ins ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "ins" attrs children

let br ?(attrs=[]) () =
  element "br" ~self_closing:true attrs []

let hr ?class_ ?(attrs=[]) () =
  let attrs = [] 
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "hr" ~self_closing:true attrs []

(** Lists *)
let ul ?id ?class_ ?role ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_data data
    |> add_attrs attrs
  in
  element "ul" attrs children

let ol ?id ?class_ ?start ?role ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "start" (Option.map string_of_int start)
    |> add_opt "role" role
    |> add_data data
    |> add_attrs attrs
  in
  element "ol" attrs children

let dl ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "dl" attrs children

let dt ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "dt" attrs children

let dd ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "dd" attrs children

let li ?id ?class_ ?role ?onclick:_ ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_data data
    |> add_attrs attrs
  in
  element "li" attrs children

(** Tables *)
let table ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "table" attrs children

let caption ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "caption" attrs children

let colgroup ?(attrs=[]) ~children () =
  element "colgroup" attrs children

let col ?span ?(attrs=[]) () =
  let attrs = []
    |> add_opt "span" (Option.map string_of_int span)
    |> add_attrs attrs
  in
  element "col" ~self_closing:true attrs []

let thead ?(attrs=[]) ~children () =
  element "thead" attrs children

let tbody ?(attrs=[]) ~children () =
  element "tbody" attrs children

let tfoot ?(attrs=[]) ~children () =
  element "tfoot" attrs children

let tr ?class_ ?(attrs=[]) ~children () =
  let attrs = [] 
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "tr" attrs children

let th ?class_ ?scope ?colspan ?rowspan ?(attrs=[]) ~children () =
  let attrs = [] 
    |> add_opt "class" class_
    |> add_opt "scope" scope
    |> add_opt "colspan" (Option.map string_of_int colspan)
    |> add_opt "rowspan" (Option.map string_of_int rowspan)
    |> add_attrs attrs
  in
  element "th" attrs children

let td ?class_ ?colspan ?rowspan ?(attrs=[]) ~children () =
  let attrs = [] 
    |> add_opt "class" class_
    |> add_opt "colspan" (Option.map string_of_int colspan)
    |> add_opt "rowspan" (Option.map string_of_int rowspan)
    |> add_attrs attrs
  in
  element "td" attrs children

(** Forms *)
let form ?id ?class_ ?action ?method_ ?enctype ?onsubmit:_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "action" action
    |> add_opt "method" method_
    |> add_opt "enctype" enctype
    |> add_attrs attrs
  in
  element "form" attrs children

let input ?id ?class_ ?type_ ?name ?value ?placeholder ?accept ?min ?max ?step
    ?(required=false) ?(disabled=false) ?(checked=false) ?(autofocus=false) ?(readonly=false)
    ?tabindex ?oninput:_ ?onchange:_ ?onkeydown:_ ?(data=[]) ?(attrs=[]) ?children:_children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "type" type_
    |> add_opt "name" name
    |> add_opt "value" value
    |> add_opt "placeholder" placeholder
    |> add_opt "accept" accept
    |> add_opt "min" min
    |> add_opt "max" max
    |> add_opt "step" step
    |> add_bool "required" required
    |> add_bool "disabled" disabled
    |> add_bool "checked" checked
    |> add_bool "autofocus" autofocus
    |> add_bool "readonly" readonly
    |> add_int "tabindex" tabindex
    |> add_data data
    |> add_attrs attrs
  in
  element "input" ~self_closing:true attrs []

let textarea ?id ?class_ ?name ?placeholder ?rows ?cols ?(required=false) ?(disabled=false) ?(autofocus=false) ?(readonly=false) ?tabindex ?oninput:_ ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "name" name
    |> add_opt "placeholder" placeholder
    |> add_opt "rows" (Option.map string_of_int rows)
    |> add_opt "cols" (Option.map string_of_int cols)
    |> add_bool "required" required
    |> add_bool "disabled" disabled
    |> add_bool "autofocus" autofocus
    |> add_bool "readonly" readonly
    |> add_int "tabindex" tabindex
    |> add_data data
    |> add_attrs attrs
  in
  element "textarea" attrs children

let select ?id ?class_ ?name ?(required=false) ?(disabled=false) ?(multiple=false) ?(autofocus=false) ?tabindex ?onchange:_ ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "name" name
    |> add_bool "required" required
    |> add_bool "disabled" disabled
    |> add_bool "multiple" multiple
    |> add_bool "autofocus" autofocus
    |> add_int "tabindex" tabindex
    |> add_data data
    |> add_attrs attrs
  in
  element "select" attrs children

let option ?value ?(selected=false) ?(disabled=false) ?(attrs=[]) ~children () =
  let attrs = [] 
    |> add_opt "value" value
    |> add_bool "selected" selected
    |> add_bool "disabled" disabled
    |> add_attrs attrs
  in
  element "option" attrs children

let optgroup ?label ?(disabled=false) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "label" label
    |> add_bool "disabled" disabled
    |> add_attrs attrs
  in
  element "optgroup" attrs children

let label ?id ?class_ ?for_ ?(attrs=[]) ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "for" for_
    |> add_attrs attrs
  in
  element "label" attrs children

let button ?id ?class_ ?type_ ?(disabled=false) ?tabindex ?aria_label ?aria_expanded ?aria_controls ?aria_haspopup ?onclick:_ ?(data=[]) ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "type" type_
    |> add_bool "disabled" disabled
    |> add_int "tabindex" tabindex
    |> add_opt "aria-label" aria_label
    |> add_opt "aria-expanded" (Option.map string_of_bool aria_expanded)
    |> add_opt "aria-controls" aria_controls
    |> add_opt "aria-haspopup" (Option.map string_of_bool aria_haspopup)
    |> add_data data
    |> add_attrs attrs
  in
  element "button" attrs children

let output ?id ?class_ ?for_ ?name ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "for" for_
    |> add_opt "name" name
    |> add_attrs attrs
  in
  element "output" attrs children

let progress ?id ?class_ ?value ?max ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "value" value
    |> add_opt "max" max
    |> add_attrs attrs
  in
  element "progress" attrs children

let meter ?id ?class_ ?value ?min ?max ?low ?high ?optimum ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "value" value
    |> add_opt "min" min
    |> add_opt "max" max
    |> add_opt "low" low
    |> add_opt "high" high
    |> add_opt "optimum" optimum
    |> add_attrs attrs
  in
  element "meter" attrs children

let fieldset ?id ?class_ ?(disabled=false) ?(attrs=[]) ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_bool "disabled" disabled
    |> add_attrs attrs
  in
  element "fieldset" attrs children

let legend ?(attrs=[]) ~children () =
  element "legend" attrs children

(** Media *)
let picture ?id ?class_ ?(attrs=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_attrs attrs
  in
  element "picture" attrs children

let img ?id ?class_ ?src ?alt ?width ?height ?loading ?srcset ?sizes ?(data=[]) ?(attrs=[]) () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "src" src
    |> add_opt "alt" alt
    |> add_opt "width" (Option.map string_of_int width)
    |> add_opt "height" (Option.map string_of_int height)
    |> add_opt "loading" loading
    |> add_opt "srcset" srcset
    |> add_opt "sizes" sizes
    |> add_data data
    |> add_attrs attrs
  in
  element "img" ~self_closing:true attrs []

(** Portal *)
let portal ?target:_ ?is_svg:_ ~children () =
  children

let video ?id ?class_ ?src ?(controls=false) ?(autoplay=false) ?(loop=false) ?(muted=false) ?poster ?(attrs=[]) ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "src" src
    |> add_opt "poster" poster
    |> add_bool "controls" controls
    |> add_bool "autoplay" autoplay
    |> add_bool "loop" loop
    |> add_bool "muted" muted
    |> add_attrs attrs
  in
  element "video" attrs children

let audio ?id ?class_ ?src ?(controls=false) ?(autoplay=false) ?(loop=false) ?(muted=false) ?(attrs=[]) ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "src" src
    |> add_bool "controls" controls
    |> add_bool "autoplay" autoplay
    |> add_bool "loop" loop
    |> add_bool "muted" muted
    |> add_attrs attrs
  in
  element "audio" attrs children

let source ?src ?type_ ?(attrs=[]) () =
  let attrs = [] 
    |> add_opt "src" src
    |> add_opt "type" type_
    |> add_attrs attrs
  in
  element "source" ~self_closing:true attrs []

let track ?kind ?src ?srclang ?label ?(attrs=[]) () =
  let attrs = []
    |> add_opt "kind" kind
    |> add_opt "src" src
    |> add_opt "srclang" srclang
    |> add_opt "label" label
    |> add_attrs attrs
  in
  element "track" ~self_closing:true attrs []

let iframe ?id ?class_ ?src ?width ?height ?title ?(attrs=[]) () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "src" src
    |> add_opt "width" width
    |> add_opt "height" height
    |> add_opt "title" title
    |> add_attrs attrs
  in
  element "iframe" attrs []

(** {1 SVG Elements} *)

module Svg = struct
  let svg ?(xmlns=true) ?id ?class_ ?style ?viewBox ?width ?height ?fill ?onclick:_ ?(attrs=[]) ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "viewBox" viewBox
      |> add_opt "width" width
      |> add_opt "height" height
      |> add_opt "fill" fill
      |> add_attrs attrs
    in
    let attrs = if xmlns then ("xmlns", svg_namespace) :: attrs else attrs in
    element "svg" attrs children

  let g ?id ?class_ ?style ?transform ?fill ?stroke ?onclick:_ ?(attrs=[]) ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "transform" transform
      |> add_opt "fill" fill
      |> add_opt "stroke" stroke
      |> add_attrs attrs
    in
    element "g" attrs children

  let circle ?id ?class_ ?style ?cx ?cy ?r ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick:_ ?(attrs=[]) ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "cx" cx
      |> add_opt "cy" cy
      |> add_opt "r" r
      |> add_opt "fill" fill
      |> add_opt "stroke" stroke
      |> add_opt "stroke-width" stroke_width
      |> add_opt "stroke-linecap" stroke_linecap
      |> add_opt "stroke-linejoin" stroke_linejoin
      |> add_attrs attrs
    in
    element "circle" attrs children

  let ellipse ?id ?class_ ?style ?cx ?cy ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick:_ ?(attrs=[]) ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "cx" cx
      |> add_opt "cy" cy
      |> add_opt "rx" rx
      |> add_opt "ry" ry
      |> add_opt "fill" fill
      |> add_opt "stroke" stroke
      |> add_opt "stroke-width" stroke_width
      |> add_opt "stroke-linecap" stroke_linecap
      |> add_opt "stroke-linejoin" stroke_linejoin
      |> add_attrs attrs
    in
    element "ellipse" attrs children

  let rect ?id ?class_ ?style ?x ?y ?width ?height ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick:_ ?(attrs=[]) ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "x" x
      |> add_opt "y" y
      |> add_opt "width" width
      |> add_opt "height" height
      |> add_opt "rx" rx
      |> add_opt "ry" ry
      |> add_opt "fill" fill
      |> add_opt "stroke" stroke
      |> add_opt "stroke-width" stroke_width
      |> add_opt "stroke-linecap" stroke_linecap
      |> add_opt "stroke-linejoin" stroke_linejoin
      |> add_attrs attrs
    in
    element "rect" attrs children

  let line ?id ?class_ ?style ?x1 ?y1 ?x2 ?y2 ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick:_ ?(attrs=[]) ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "x1" x1
      |> add_opt "y1" y1
      |> add_opt "x2" x2
      |> add_opt "y2" y2
      |> add_opt "stroke" stroke
      |> add_opt "stroke-width" stroke_width
      |> add_opt "stroke-linecap" stroke_linecap
      |> add_opt "stroke-linejoin" stroke_linejoin
      |> add_attrs attrs
    in
    element "line" attrs children

  let polyline ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick:_ ?(attrs=[]) ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "points" points
      |> add_opt "fill" fill
      |> add_opt "stroke" stroke
      |> add_opt "stroke-width" stroke_width
      |> add_opt "stroke-linecap" stroke_linecap
      |> add_opt "stroke-linejoin" stroke_linejoin
      |> add_attrs attrs
    in
    element "polyline" attrs children

  let polygon ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick:_ ?(attrs=[]) ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "points" points
      |> add_opt "fill" fill
      |> add_opt "stroke" stroke
      |> add_opt "stroke-width" stroke_width
      |> add_opt "stroke-linecap" stroke_linecap
      |> add_opt "stroke-linejoin" stroke_linejoin
      |> add_attrs attrs
    in
    element "polygon" attrs children

  let path ?id ?class_ ?style ?d ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?fill_rule ?clip_rule ?onclick:_ ?(attrs=[]) ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "d" d
      |> add_opt "fill" fill
      |> add_opt "stroke" stroke
      |> add_opt "stroke-width" stroke_width
      |> add_opt "stroke-linecap" stroke_linecap
      |> add_opt "stroke-linejoin" stroke_linejoin
      |> add_opt "fill-rule" fill_rule
      |> add_opt "clip-rule" clip_rule
      |> add_attrs attrs
    in
    element "path" attrs children

  let text_ ?id ?class_ ?style ?x ?y ?dx ?dy ?text_anchor ?font_size ?font_family ?fill ?stroke ?stroke_width ?onclick:_ ?(attrs=[]) ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "x" x
      |> add_opt "y" y
      |> add_opt "dx" dx
      |> add_opt "dy" dy
      |> add_opt "text-anchor" text_anchor
      |> add_opt "font-size" font_size
      |> add_opt "font-family" font_family
      |> add_opt "fill" fill
      |> add_opt "stroke" stroke
      |> add_opt "stroke-width" stroke_width
      |> add_attrs attrs
    in
    element "text" attrs children

  let tspan ?id ?class_ ?x ?y ?dx ?dy ?fill ?onclick:_ ?(attrs=[]) ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "x" x
      |> add_opt "y" y
      |> add_opt "dx" dx
      |> add_opt "dy" dy
      |> add_opt "fill" fill
      |> add_attrs attrs
    in
    element "tspan" attrs children

  let defs ?id ?(attrs=[]) ~children () =
    let attrs = [] 
      |> add_opt "id" id 
      |> add_attrs attrs
    in
    element "defs" attrs children

  let use ?id ?class_ ?href ?x ?y ?width ?height ?onclick:_ ?(attrs=[]) () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "href" href
      |> add_opt "x" x
      |> add_opt "y" y
      |> add_opt "width" width
      |> add_opt "height" height
      |> add_attrs attrs
    in
    element "use" ~self_closing:true attrs []

  let symbol ?id ?viewBox ?(attrs=[]) ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "viewBox" viewBox
      |> add_attrs attrs
    in
    element "symbol" attrs children

  let clipPath ?id ?(attrs=[]) ~children () =
    let attrs = [] 
      |> add_opt "id" id 
      |> add_attrs attrs
    in
    element "clipPath" attrs children

  let mask ?id ?(attrs=[]) ~children () =
    let attrs = [] 
      |> add_opt "id" id 
      |> add_attrs attrs
    in
    element "mask" attrs children

  let linearGradient ?id ?x1 ?y1 ?x2 ?y2 ?gradientUnits ?gradientTransform ?(attrs=[]) ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "x1" x1
      |> add_opt "y1" y1
      |> add_opt "x2" x2
      |> add_opt "y2" y2
      |> add_opt "gradientUnits" gradientUnits
      |> add_opt "gradientTransform" gradientTransform
      |> add_attrs attrs
    in
    element "linearGradient" attrs children

  let radialGradient ?id ?cx ?cy ?r ?fx ?fy ?gradientUnits ?gradientTransform ?(attrs=[]) ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "cx" cx
      |> add_opt "cy" cy
      |> add_opt "r" r
      |> add_opt "fx" fx
      |> add_opt "fy" fy
      |> add_opt "gradientUnits" gradientUnits
      |> add_opt "gradientTransform" gradientTransform
      |> add_attrs attrs
    in
    element "radialGradient" attrs children

  let stop ?offset ?stop_color ?stop_opacity ?(attrs=[]) () =
    let attrs = []
      |> add_opt "offset" offset
      |> add_opt "stop-color" stop_color
      |> add_opt "stop-opacity" stop_opacity
      |> add_attrs attrs
    in
    element "stop" ~self_closing:true attrs []

  let image ?id ?class_ ?href ?x ?y ?width ?height ?preserveAspectRatio ?(attrs=[]) () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "href" href
      |> add_opt "x" x
      |> add_opt "y" y
      |> add_opt "width" width
      |> add_opt "height" height
      |> add_opt "preserveAspectRatio" preserveAspectRatio
      |> add_attrs attrs
    in
    element "image" ~self_closing:true attrs []

  let foreignObject ?id ?class_ ?x ?y ?width ?height ?(attrs=[]) ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "x" x
      |> add_opt "y" y
      |> add_opt "width" width
      |> add_opt "height" height
      |> add_attrs attrs
    in
    element "foreignObject" attrs children
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

(** Fragment *)
let fragment nodes = Fragment nodes
let empty = Fragment []

(** Render document *)
let render_document ?(doctype=true) node =
  let doc = if doctype then "<!DOCTYPE html>\n" else "" in
  doc ^ to_string node
