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

let of_path path =
  if String.equal path "/" then Some Posts
  else if String.equal path "/users" then Some Users
  else if String.length path > 7 && String.sub path 0 7 = "/posts/" then
    let id_str = String.sub path 7 (String.length path - 7) in
    Option.map (fun id -> Post id) (int_of_string_opt id_str)
  else if String.length path > 7 && String.sub path 0 7 = "/users/" then
    let id_str = String.sub path 7 (String.length path - 7) in
    Option.map (fun id -> User id) (int_of_string_opt id_str)
  else
    None

let is_nav_active ~current_path = function
  | Posts ->
    String.equal current_path "/"
    || (String.length current_path > 7 && String.sub current_path 0 7 = "/posts/")
  | Users ->
    String.equal current_path "/users"
    || (String.length current_path > 7 && String.sub current_path 0 7 = "/users/")
  | Post _
  | User _ -> false
