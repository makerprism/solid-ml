(** Error boundaries for catching and handling errors (browser version).
    
    ErrorBoundary catches exceptions thrown during rendering and displays
    a fallback UI. This matches SolidJS's ErrorBoundary behavior.
    
    {[
      ErrorBoundary.make
        ~fallback:(fun ~error ~reset ->
          Html.div ~children:[
            Html.text ("Error: " ^ error);
            Html.button ~onclick:(fun _ -> reset ()) ~children:[Html.text "Retry"] ()
          ] ())
        (fun () ->
          let data = Resource.read_suspense ~default user_resource in
          render data
        )
    ]}
*)

(** {1 Types} *)

(** State of the error boundary *)
type error_state =
  | No_error
  | Has_error of string

(** {1 Error Boundary} *)

(** Create an error boundary.
    
    Catches any exception thrown by [children] and renders [fallback] instead.
    The fallback receives the error message and a reset function. *)
let make ~fallback children =
  (* Signal to track error state *)
  let state = Reactive_core.create_signal No_error in
  let set_state s = Reactive_core.set_signal state s in
  
  (* Attempt counter to force re-render on reset *)
  let attempt = ref 0 in
  
  (* Reset function clears error and increments attempt *)
  let reset () =
    incr attempt;
    set_state No_error
  in
  
  (* Create memo that handles rendering *)
  let content = Reactive_core.create_memo (fun () ->
    match Reactive_core.get_signal state with
    | Has_error msg ->
      (* In error state - render fallback *)
      fallback ~error:msg ~reset
    | No_error ->
      (* Try to render children *)
      let _ = !attempt in (* Force dependency on attempt for re-render *)
      let handle_error exn =
        let msg = Dom.exn_to_string exn in
        set_state (Has_error msg)
      in
      try
        Reactive_core.with_error_handler handle_error children
      with exn ->
        let msg = Dom.exn_to_string exn in
        set_state (Has_error msg);
        fallback ~error:msg ~reset
  ) in
  Reactive_core.get_memo content

(** Simpler error boundary without reset capability. *)
let make_simple ~fallback children =
  try
    children ()
  with exn ->
    let msg = Dom.exn_to_string exn in
    fallback msg
