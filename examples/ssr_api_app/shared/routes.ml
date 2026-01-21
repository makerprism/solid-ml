type t =
  | Posts
  | Users
  | Post of int
  | User of int

let path = function
  | Posts -> "/"
  | Users -> "/users"
  | Post id -> "/posts/" ^ string_of_int id
  | User id -> "/users/" ^ string_of_int id

let label = function
  | Posts -> "Posts"
  | Users -> "Users"
  | Post _ -> "Post"
  | User _ -> "User"

let nav_items = [ Posts; Users ]

let normalize_path path =
  let len = String.length path in
  if len > 1 && path.[len - 1] = '/' then
    String.sub path 0 (len - 1)
  else
    path

let of_path path =
  let normalized = normalize_path path in
  if String.equal normalized "/" then Some Posts
  else if String.equal normalized "/users" then Some Users
  else if String.length normalized > 7 && String.sub normalized 0 7 = "/posts/" then
    let id_str = String.sub normalized 7 (String.length normalized - 7) in
    Option.map (fun id -> Post id) (int_of_string_opt id_str)
  else if String.length normalized > 7 && String.sub normalized 0 7 = "/users/" then
    let id_str = String.sub normalized 7 (String.length normalized - 7) in
    Option.map (fun id -> User id) (int_of_string_opt id_str)
  else
    None

let is_nav_active ~current_path =
  let normalized = normalize_path current_path in
  function
  | Posts ->
    String.equal normalized "/"
    || (String.length normalized > 7 && String.sub normalized 0 7 = "/posts/")
  | Users ->
    String.equal normalized "/users"
    || (String.length normalized > 7 && String.sub normalized 0 7 = "/users/")
  | Post _
  | User _ -> false
