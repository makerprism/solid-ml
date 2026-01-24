type t =
  | Http_error of int
  | Json_error of string
  | Network_error of string
  | Parse_error of string

let to_string = function
  | Http_error code -> "HTTP " ^ string_of_int code
  | Json_error msg -> "JSON error: " ^ msg
  | Network_error msg -> "Network error: " ^ msg
  | Parse_error msg -> "Parse error: " ^ msg
