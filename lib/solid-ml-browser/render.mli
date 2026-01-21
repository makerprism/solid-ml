(** Client-side rendering and hydration. *)

(** {1 Rendering} *)

val render : Dom.element -> (unit -> Html.node) -> (unit -> unit)
(** [render root component] renders a component into a DOM element,
    replacing any existing content.
    
    Returns a dispose function that cleans up effects and event handlers. *)

val render_strict :
  Dom.element -> (Reactive.Strict.token -> Html.node) -> (unit -> unit)
(** [render_strict root component] is like [render] but passes a
    [Reactive.Strict] token to enforce runtime usage at compile time. *)

val render_append : Dom.element -> (unit -> Html.node) -> (unit -> unit)
(** [render_append root component] renders a component, appending to
    existing content. Returns a dispose function. *)

(** {1 Hydration} *)

val hydrate : Dom.element -> (unit -> Html.node) -> (unit -> unit)
(** [hydrate root component] adopts server-rendered HTML and attaches
    reactive bindings.
    
    The component must produce the same structure as the server render.
    Returns a dispose function. *)

val hydrate_with :
  Dom.element ->
  ?decode:(Js.Json.t -> 'a option) ->
  default:'a ->
  ('a -> Html.node) ->
  (unit -> unit)
(** [hydrate_with root ~default component] hydrates using server-provided data.

    If [decode] is provided, it is applied to [get_hydration_data ()]. When
    decoding fails or no data is present, [default] is used. *)

val get_hydration_data : unit -> Js.Json.t option
(** Get hydration data embedded by the server in window.__SOLID_ML_DATA__ *)

(** {1 Development} *)

val render_hmr : Dom.element -> (unit -> Html.node) -> (unit -> unit)
(** [render_hmr root component] renders with hot module replacement support.
    Re-calling disposes the previous render automatically. *)
