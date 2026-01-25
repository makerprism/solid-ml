type t =
  | Home
  | Counter
  | Todos
  | Filters
  | Inline_edit
  | Async
  | Undo_redo
  | Theme
  | Wizard
  | Keyed
  | Template_keyed

let path = function
  | Home -> "/"
  | Counter -> "/counter"
  | Todos -> "/todos"
  | Filters -> "/filters"
  | Inline_edit -> "/inline-edit"
  | Async -> "/async"
  | Undo_redo -> "/undo-redo"
  | Theme -> "/theme"
  | Wizard -> "/wizard"
  | Keyed -> "/keyed"
  | Template_keyed -> "/template-keyed"

let label = function
  | Home -> "Home"
  | Counter -> "Counter"
  | Todos -> "Todos"
  | Filters -> "Filters"
  | Inline_edit -> "Inline-Edit"
  | Async -> "Async"
  | Undo_redo -> "Undo-Redo"
  | Theme -> "Theme"
  | Wizard -> "Wizard"
  | Keyed -> "Keyed"
  | Template_keyed -> "Template-Keyed"

let all = [ Home; Counter; Todos; Filters; Inline_edit; Async; Undo_redo; Theme; Wizard; Keyed; Template_keyed ]

let of_path path =
  match path with
  | "/" -> Some Home
  | "/counter" -> Some Counter
  | "/todos" -> Some Todos
  | "/filters" -> Some Filters
  | "/inline-edit" -> Some Inline_edit
  | "/async" -> Some Async
  | "/undo-redo" -> Some Undo_redo
  | "/theme" -> Some Theme
  | "/wizard" -> Some Wizard
  | "/keyed" -> Some Keyed
  | "/template-keyed" -> Some Template_keyed
  | _ -> None

let is_active ~current_path route =
  String.equal current_path (path route)
