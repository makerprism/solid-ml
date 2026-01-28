module Error = Ssr_api_shared.Error

type t = Obj.t

let parse_raw : string -> t option = [%mel.raw {|
  function(input) {
    try {
      return JSON.parse(input);
    } catch (e) {
      return null;
    }
  }
|}]

let get_prop : t -> string -> t option = [%mel.raw {|
  function(obj, key) {
    if (obj && typeof obj === "object" && key in obj) {
      return obj[key];
    }
    return null;
  }
|}]

let as_string : t -> string option = [%mel.raw {|
  function(value) {
    return (typeof value === "string") ? value : null;
  }
|}]

let as_int : t -> int option = [%mel.raw {|
  function(value) {
    if (typeof value === "number" && isFinite(value)) {
      return Math.trunc(value);
    }
    return null;
  }
|}]

let as_array : t -> t array option = [%mel.raw {|
  function(value) {
    return Array.isArray(value) ? value : null;
  }
|}]

let parse input =
  match parse_raw input with
  | Some value -> Ok value
  | None -> Error (Error.Json_error "Invalid JSON")

let member json key =
  get_prop json key

let to_string json =
  match as_string json with
  | Some value -> Ok value
  | None -> Error (Error.Parse_error "Expected string")

let to_int json =
  match as_int json with
  | Some value -> Ok value
  | None -> Error (Error.Parse_error "Expected int")

let to_list json =
  match as_array json with
  | Some value -> Ok (Array.to_list value)
  | None -> Error (Error.Parse_error "Expected list")
