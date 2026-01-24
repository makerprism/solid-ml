type json = string

let state_key : (string, json) Hashtbl.t Domain.DLS.key =
  Domain.DLS.new_key (fun () -> Hashtbl.create 8)

let table () = Domain.DLS.get state_key

let key ?namespace name =
  match namespace with
  | None -> name
  | Some "" -> name
  | Some ns -> ns ^ ":" ^ name

let reset () = Hashtbl.clear (table ())

let set ~key (value : json) =
  Hashtbl.replace (table ()) key value

let set_encoded ~key ~encode value =
  set ~key (encode value)

let get ~key = Hashtbl.find_opt (table ()) key

let escape_string (s : string) : string =
  let buf = Buffer.create (String.length s) in
  String.iter
    (function
      | '"' -> Buffer.add_string buf "\\\""
      | '\\' -> Buffer.add_string buf "\\\\"
      | '\b' -> Buffer.add_string buf "\\b"
      | '\012' -> Buffer.add_string buf "\\f"
      | '\n' -> Buffer.add_string buf "\\n"
      | '\r' -> Buffer.add_string buf "\\r"
      | '\t' -> Buffer.add_string buf "\\t"
      | c when Char.code c < 0x20 ->
        Buffer.add_string buf (Printf.sprintf "\\u%04x" (Char.code c))
      | c -> Buffer.add_char buf c)
    s;
  Buffer.contents buf

let encode_string (s : string) : json =
  "\"" ^ escape_string s ^ "\""

let encode_int (v : int) : json = string_of_int v
let encode_float (v : float) : json =
  if Float.is_finite v then string_of_float v else "null"

let encode_bool (v : bool) : json = if v then "true" else "false"
let encode_null : json = "null"

let encode_list (items : json list) : json =
  "[" ^ String.concat "," items ^ "]"

let encode_object (fields : (string * json) list) : json =
  let entries =
    List.map (fun (key, value) -> encode_string key ^ ":" ^ value) fields
  in
  "{" ^ String.concat "," entries ^ "}"

let encode_resource_ready data : json =
  encode_object [
    ("status", encode_string "ready");
    ("data", data);
  ]

let encode_resource_error message : json =
  encode_object [
    ("status", encode_string "error");
    ("error", encode_string message);
  ]

let encode_resource_loading () : json =
  encode_object [
    ("status", encode_string "loading");
  ]

let to_json () : json =
  let entries =
    Hashtbl.fold
      (fun key value acc -> (encode_string key ^ ":" ^ value) :: acc)
      (table ())
      []
  in
  "{" ^ String.concat "," (List.rev entries) ^ "}"

let to_script () : string =
  "<script>window.__SOLID_ML_DATA__ = " ^ to_json () ^ ";</script>"
