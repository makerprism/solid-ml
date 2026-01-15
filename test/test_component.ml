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

(** Instantiate Counter for SSR *)
module SsrCounter = Counter(Solid_ml_ssr.Env)

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
  let _ = (module Solid_ml_ssr.Env : Component.COMPONENT_ENV) in
  print_endline "  PASSED"

let test_ssr_env_satisfies_template_env () =
  print_endline "Test: SSR environment satisfies template Env_intf";
  let _ =
    (module Solid_ml_ssr.Env : Solid_ml_template_runtime.Env_intf.TEMPLATE_ENV)
  in
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
  let module SsrClick = ClickCounter(Solid_ml_ssr.Env) in
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
  let module SsrStateful = StatefulComponent(Solid_ml_ssr.Env) in
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
  let module SsrOuter = Outer(Solid_ml_ssr.Env) in
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
