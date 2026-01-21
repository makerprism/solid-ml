type t =
  | Home
  | Counter
  | Todos
  | Keyed
  | Template_keyed

let path = function
  | Home -> "/"
  | Counter -> "/counter"
  | Todos -> "/todos"
  | Keyed -> "/keyed"
  | Template_keyed -> "/template-keyed"

let label = function
  | Home -> "Home"
  | Counter -> "Counter"
  | Todos -> "Todos"
  | Keyed -> "Keyed"
  | Template_keyed -> "Template-Keyed"

let all = [ Home; Counter; Todos; Keyed; Template_keyed ]

let of_path path =
  match path with
  | "/" -> Some Home
  | "/counter" -> Some Counter
  | "/todos" -> Some Todos
  | "/keyed" -> Some Keyed
  | "/template-keyed" -> Some Template_keyed
  | _ -> None

let is_active ~current_path route =
  String.equal current_path (path route)
