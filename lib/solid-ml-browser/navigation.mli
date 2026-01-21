(** Simple SPA navigation helpers. *)

type dispose = unit -> unit

type history_mode = [ `Push | `Replace | `None ]

(** Bind click handlers for internal links.

    - [root] limits the query to a subtree (defaults to document).
    - [selector] defaults to ["a[href]"]
    - [history] defaults to [`Push].
    - Links tagged with [data-spa-replace] override [history] to [`Replace].
    - Links tagged with [data-spa-bound] are skipped to avoid double binding.
    - Only handles links whose [href] starts with [/]. *)
val bind_links :
  ?root:Dom.element ->
  ?selector:string ->
  ?history:history_mode ->
  on_navigate:(string -> unit) ->
  unit ->
  dispose

(** Bind a popstate listener that calls [on_navigate]. *)
val bind_popstate : on_navigate:(string -> unit) -> unit -> dispose

(** Bind both link handlers and popstate listener. *)
val bind_spa :
  ?root:Dom.element ->
  ?selector:string ->
  ?history:history_mode ->
  on_navigate:(string -> unit) ->
  unit ->
  dispose
