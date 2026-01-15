(** Tests for the Component functor abstraction *)

open Solid_ml

(** {1 Test Component}

    A simple counter component that works with the COMPONENT_ENV functor. *)
module Counter (Env : Component.COMPONENT_ENV) = struct
  open Env

  let render ~initial () =
    let count, _set_count = Signal.create initial in
    Html.div ~children:[
      Html.p ~class_:"counter-label" ~children:[Html.text "Count: "] ();
      Html.div ~class_:"value" ~children:[Html.reactive_text count] ()
    ] ()
end

(** {1 SSR Environment Module}

    This module adapts Solid_ml_ssr.Html to satisfy COMPONENT_ENV.
    Note: We don't constrain with :COMPONENT_ENV to keep types transparent
    for Render.to_string compatibility. *)
module Ssr_env = struct
  type 'a signal = 'a Signal.t

  module Signal = struct
    type 'a t = 'a signal
    let create ?equals = Signal.create ?equals
    let get = Signal.get
    let peek = Signal.peek
    let update = Signal.update
  end

  module Html = struct
    type node = Solid_ml_ssr.Html.node
    type 'a signal = 'a Signal.t
    type event = Solid_ml_ssr.Html.event

    let text = Solid_ml_ssr.Html.text
    let int = Solid_ml_ssr.Html.int
    let float = Solid_ml_ssr.Html.float
    let fragment = Solid_ml_ssr.Html.fragment
    let reactive_text = Solid_ml_ssr.Html.reactive_text
    let reactive_text_of = Solid_ml_ssr.Html.reactive_text_of
    let reactive_text_string = Solid_ml_ssr.Html.reactive_text_string

    module Template = struct
      include Solid_ml_ssr.Html.Template
      let hydrate ~root:_ template = Solid_ml_ssr.Html.Template.instantiate template
    end

    let div = Solid_ml_ssr.Html.div
    let span = Solid_ml_ssr.Html.span
    let p = Solid_ml_ssr.Html.p
    let pre = Solid_ml_ssr.Html.pre
    let code = Solid_ml_ssr.Html.code
    let h1 = Solid_ml_ssr.Html.h1
    let h2 = Solid_ml_ssr.Html.h2
    let h3 = Solid_ml_ssr.Html.h3
    let h4 = Solid_ml_ssr.Html.h4
    let h5 = Solid_ml_ssr.Html.h5
    let h6 = Solid_ml_ssr.Html.h6
    let header = Solid_ml_ssr.Html.header
    let footer = Solid_ml_ssr.Html.footer
    let main = Solid_ml_ssr.Html.main
    let nav = Solid_ml_ssr.Html.nav
    let section = Solid_ml_ssr.Html.section
    let article = Solid_ml_ssr.Html.article
    let aside = Solid_ml_ssr.Html.aside
    let a = Solid_ml_ssr.Html.a
    let strong = Solid_ml_ssr.Html.strong
    let em = Solid_ml_ssr.Html.em
    let br = Solid_ml_ssr.Html.br
    let hr = Solid_ml_ssr.Html.hr
    let ul = Solid_ml_ssr.Html.ul
    let ol = Solid_ml_ssr.Html.ol
    let li = Solid_ml_ssr.Html.li
    let table = Solid_ml_ssr.Html.table
    let thead = Solid_ml_ssr.Html.thead
    let tbody = Solid_ml_ssr.Html.tbody
    let tfoot = Solid_ml_ssr.Html.tfoot
    let tr = Solid_ml_ssr.Html.tr
    let th = Solid_ml_ssr.Html.th
    let td = Solid_ml_ssr.Html.td
    let form = Solid_ml_ssr.Html.form
    let input = Solid_ml_ssr.Html.input
    let textarea = Solid_ml_ssr.Html.textarea
    let select = Solid_ml_ssr.Html.select
    let option = Solid_ml_ssr.Html.option
    let label = Solid_ml_ssr.Html.label
    let button = Solid_ml_ssr.Html.button
    let img = Solid_ml_ssr.Html.img
  end
end

(** Instantiate Counter for SSR *)
module SsrCounter = Counter(Ssr_env)

(** Helper to check if string contains substring *)
let contains s sub =
  let len = String.length sub in
  let rec check i =
    if i + len > String.length s then false
    else if String.sub s i len = sub then true
    else check (i + 1)
  in
  check 0

(* ============ Tests ============ *)

let test_ssr_env_satisfies_interface () =
  print_endline "Test: SSR environment satisfies COMPONENT_ENV";
  (* The fact that this compiles proves the interface is satisfied *)
  let _ = (module Ssr_env : Component.COMPONENT_ENV) in
  print_endline "  PASSED"

let test_ssr_env_satisfies_template_env () =
  print_endline "Test: SSR environment satisfies TEMPLATE_ENV";
  let module Env = struct
    include Ssr_env
    module Effect = Solid_ml.Effect
    module Owner = Solid_ml.Owner
  end in
  let _ = (module Env : Component.TEMPLATE_ENV) in
  print_endline "  PASSED"

let test_component_functor_instantiation () =
  print_endline "Test: Component functor can be instantiated with SSR";
  (* Create a component and render it *)
  let node = Solid_ml_ssr.Render.to_string (fun () ->
    SsrCounter.render ~initial:42 ()
  ) in
  assert (contains node "42");
  assert (contains node "counter-label");
  print_endline "  PASSED"

let test_component_with_event_handlers () =
  print_endline "Test: Component can use event handlers (ignored on SSR)";
  (* Define a component that uses onclick *)
  let module ClickCounter (Env : Component.COMPONENT_ENV) = struct
    open Env
    let render () =
      let count, _set_count = Signal.create 0 in
      Html.div ~children:[
        Html.button ~onclick:(fun _ -> Signal.update count succ)
          ~children:[Html.text "+"] ();
        Html.reactive_text count
      ] ()
  end in
  let module SsrClick = ClickCounter(Ssr_env) in
  let html = Solid_ml_ssr.Render.to_string (fun () -> SsrClick.render ()) in
  assert (contains html "<button>");
  assert (contains html "0");  (* Initial value *)
  (* Should not have onclick in HTML (ignored on SSR) *)
  assert (not (contains html "onclick"));
  print_endline "  PASSED"

let test_signal_operations_in_component () =
  print_endline "Test: Signal operations work within component";
  let module StatefulComponent (Env : Component.COMPONENT_ENV) = struct
    open Env
    let render () =
      let count, _set_count = Signal.create ~equals:(=) 10 in
      let value = Signal.peek count in
      Html.div ~children:[
        Html.text (string_of_int value)
      ] ()
  end in
  let module SsrStateful = StatefulComponent(Ssr_env) in
  let html = Solid_ml_ssr.Render.to_string (fun () -> SsrStateful.render ()) in
  assert (contains html "10");
  print_endline "  PASSED"

let test_nested_components () =
  print_endline "Test: Components can be nested";
  let module Inner (Env : Component.COMPONENT_ENV) = struct
    open Env
    let render ~label () =
      Html.span ~class_:"inner" ~children:[Html.text label] ()
  end in
  let module Outer (Env : Component.COMPONENT_ENV) = struct
    module I = Inner(Env)
    open Env
    let render () =
      Html.div ~class_:"outer" ~children:[
        I.render ~label:"Hello" ();
        I.render ~label:"World" ()
      ] ()
  end in
  let module SsrOuter = Outer(Ssr_env) in
  let html = Solid_ml_ssr.Render.to_string (fun () -> SsrOuter.render ()) in
  assert (contains html "outer");
  assert (contains html "inner");
  assert (contains html "Hello");
  assert (contains html "World");
  print_endline "  PASSED"

(* ============ Main ============ *)

let () =
  print_endline "\n=== Component Functor Tests ===\n";

  print_endline "-- Interface Tests --";
  test_ssr_env_satisfies_interface ();
  test_ssr_env_satisfies_template_env ();

  print_endline "\n-- Functor Instantiation Tests --";
  test_component_functor_instantiation ();
  test_component_with_event_handlers ();
  test_signal_operations_in_component ();
  test_nested_components ();

  print_endline "\n=== All tests passed! ===\n"
