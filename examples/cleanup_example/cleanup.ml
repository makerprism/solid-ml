(** Cleanup example for solid-ml-browser.

    This example demonstrates the three cleanup APIs available in solid-ml:

    1. Owner.on_cleanup - Register cleanup functions with the current owner
    2. Effect.create_with_cleanup - Effects that return cleanup functions
    3. Render.render / Render.hydrate - Return dispose functions

    Proper cleanup is critical for SPAs to prevent memory leaks when
    navigating between pages or when the page unloads.

    Build with: dune build @melange
    Then open index.html in a browser.
*)

open Solid_ml_browser

module Strict = Reactive.Strict
module Owner = Reactive.Owner

(** {1 Cleanup API 1: Effect.create_with_cleanup} *)

(** A timer component that uses Effect.create_with_cleanup.

    The effect returns a cleanup function that clears the interval
    when the component is disposed. *)
let timer_component token =
  let count, _set_count = Strict.create_signal token 0 in

  (* Effect with cleanup - runs on initial execution and re-execution *)
  Strict.create_effect_with_cleanup token (fun () ->
    Dom.log "Timer effect: starting interval";

    (* Start a timer that increments the counter every second *)
    let interval_id = Dom.set_interval (fun () ->
      Strict.update_signal token count (fun n -> n + 1)
    ) 1000 in

    (* Return cleanup function - clears the timer *)
    fun () ->
      Dom.clear_interval interval_id;
      Dom.log "Timer cleanup: cleared interval"
  );

  Html.(
    div ~class_:"timer" ~children:[
      text "Timer: ";
      Reactive.text count;
      text " seconds";
    ] ()
  )

(** {1 Cleanup API 2: Owner.on_cleanup} *)

(** A resource tracking component that registers multiple cleanup functions.

    Uses Owner.on_cleanup to register cleanup that runs when the
    component's owner is disposed. *)
let resource_component token =
  let messages, _set_messages = Strict.create_signal token [] in

  (* Simulate adding a resource that needs cleanup *)
  let add_resource () =
    let resource_id = Random.int 10000 in

    (* Register cleanup for this specific resource *)
    Owner.on_cleanup (fun () ->
      Dom.log ("Resource cleanup: freeing resource " ^ string_of_int resource_id)
    );

    Strict.update_signal token messages (fun msgs ->
      ("Added resource " ^ string_of_int resource_id) :: msgs
    )
  in

  Html.(
    div ~class_:"resource-demo" ~children:[
      h3 ~children:[text "Resource Cleanup Demo"] ();
      p ~children:[text "Click the button to add resources with cleanup handlers."] ();
      button
        ~onclick:(fun _ -> add_resource ())
        ~children:[text "Add Resource"]
        ();
      div ~class_:"messages" ~children:[
        Reactive.text_of (fun msgs ->
          if msgs = [] then "No resources added"
          else String.concat "\n" (List.rev msgs)
        ) messages
      ] ();
    ] ()
  )

(** {1 Cleanup API 3: Render.dispose} *)

(** Main component that demonstrates proper disposal on page unload.

    The render/hydrate functions return a dispose function that cleans
    up all effects and event handlers when called. This should be called
    on page unload to prevent memory leaks. *)
let main_component token =
  Html.(
    div ~id:"app" ~class_:"cleanup-demo" ~children:[
      h1 ~children:[text "solid-ml Cleanup Demo"] ();
      p ~children:[text "This page demonstrates the three cleanup APIs in solid-ml."] ();

      hr () ;

      h2 ~children:[text "1. Effect with Cleanup"] ();
      p ~children:[text "The timer below uses Effect.create_with_cleanup."] ();
      p ~children:[text "The timer effect will be cleaned up on page unload."] ();

      (* Timer component - demonstrates cleanup via create_effect_with_cleanup *)
      timer_component token;

      hr () ;

      h2 ~children:[text "2. Owner.on_cleanup"] ();
      resource_component token;

      hr () ;

      h2 ~children:[text "3. Render Dispose"] ();
      p ~children:[text "This page properly disposes all effects on unload."] ();
      p ~children:[text "Check the console when leaving this page."] ();
    ] ()
  )

(** {1 Main Entry Point} *)

let () =
  match Dom.get_element_by_id (Dom.document ()) "app" with
  | Some root ->
    (* Render the component and get the dispose function *)
    let dispose = Render.render_strict root main_component in

    (* Register cleanup on page unload - critical for SPAs! *)
    Dom.on_unload (fun _evt ->
      Dom.log "Page unload: disposing all effects and handlers";
      dispose ();
      Dom.log "Page unload: disposal complete"
    );

    Dom.log "solid-ml cleanup demo mounted! Check console for cleanup messages."
  | None ->
    Dom.error "Could not find #app element"
