type t = Yojson.Basic.t

let parse input =
  try Ok (Yojson.Basic.from_string input)
  with exn ->
    Error (Ssr_api_shared.Error.Json_error (Printexc.to_string exn))

let member json key =
  try
    match Yojson.Basic.Util.member key json with
    | `Null -> None
    | value -> Some value
  with _ -> None

let to_int json =
  try Ok (Yojson.Basic.Util.to_int json)
  with exn ->
    Error (Ssr_api_shared.Error.Parse_error (Printexc.to_string exn))

let to_string json =
  try Ok (Yojson.Basic.Util.to_string json)
  with exn ->
    Error (Ssr_api_shared.Error.Parse_error (Printexc.to_string exn))

let to_list json =
  try Ok (Yojson.Basic.Util.to_list json)
  with exn ->
    Error (Ssr_api_shared.Error.Parse_error (Printexc.to_string exn))
