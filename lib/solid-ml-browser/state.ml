type json = Js.Json.t

let key ?namespace name =
  match namespace with
  | None -> name
  | Some "" -> name
  | Some ns -> ns ^ ":" ^ name

let get_data () = Js.Nullable.toOption (Dom.get_hydration_data ())

let get ~key : json option =
  match get_data () with
  | None -> None
  | Some data ->
    (match Js.Json.decodeObject data with
     | None -> None
     | Some obj -> Js.Dict.get obj key)

let set ~key (value : json) : unit =
  let _ = (key, value) in
  [%mel.raw
    {| (function(key, value) { if (window.__SOLID_ML_DATA__ == null) window.__SOLID_ML_DATA__ = {}; window.__SOLID_ML_DATA__[key] = value; })(key, value) |}]

let set_encoded ~key ~encode value =
  set ~key (encode value)

let decode ~key ~decode ~default =
  match get ~key with
  | Some json -> (match decode json with Some v -> v | None -> default)
  | None -> default

let encode_string (v : string) : json = Js.Json.string v
let encode_int (v : int) : json = Js.Json.number (float_of_int v)
let encode_float (v : float) : json = Js.Json.number v
let encode_bool (v : bool) : json = Js.Json.boolean v
let encode_null : json = Js.Json.null

let encode_list (items : json list) : json =
  Js.Json.array (Array.of_list items)

let encode_object (fields : (string * json) list) : json =
  let dict = Js.Dict.empty () in
  List.iter (fun (key, value) -> Js.Dict.set dict key value) fields;
  Js.Json.object_ dict
