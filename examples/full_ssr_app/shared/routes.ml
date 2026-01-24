type t =
  | Home
  | Counter
  | Todos
  | Filters
  | Inline_edit
  | Keyed
  | Template_keyed

let path = function
  | Home -> "/"
  | Counter -> "/counter"
  | Todos -> "/todos"
  | Filters -> "/filters"
  | Inline_edit -> "/inline-edit"
  | Keyed -> "/keyed"
  | Template_keyed -> "/template-keyed"

let label = function
  | Home -> "Home"
  | Counter -> "Counter"
  | Todos -> "Todos"
  | Filters -> "Filters"
  | Inline_edit -> "Inline-Edit"
  | Keyed -> "Keyed"
  | Template_keyed -> "Template-Keyed"

let all = [ Home; Counter; Todos; Filters; Inline_edit; Keyed; Template_keyed ]

let of_path path =
  match path with
  | "/" -> Some Home
  | "/counter" -> Some Counter
  | "/todos" -> Some Todos
  | "/filters" -> Some Filters
  | "/inline-edit" -> Some Inline_edit
  | "/keyed" -> Some Keyed
  | "/template-keyed" -> Some Template_keyed
  | _ -> None

let is_active ~current_path route =
  String.equal current_path (path route)
