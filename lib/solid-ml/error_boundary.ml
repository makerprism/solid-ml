(** Error boundaries for catching and handling errors.
    
    ErrorBoundary catches exceptions thrown during rendering and displays
    a fallback UI. This is useful for:
    - Catching errors from Resource.read_suspense when a resource fails
    - Catching any other rendering errors
    - Providing a "reset" mechanism to retry
    
    This matches SolidJS's ErrorBoundary behavior.
    
    {[
      ErrorBoundary.make
        ~fallback:(fun ~error ~reset ->
          Html.div [] [
            Html.text ("Error: " ^ error);
            Html.button ~on_click:(fun _ -> reset ()) [Html.text "Retry"]
          ])
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
    The fallback receives the error message and a reset function that will
    re-attempt rendering the children.
    
    @param fallback Function that renders error state. Receives:
      - [~error]: The error message (from Printexc.to_string)
      - [~reset]: Function to call to retry rendering children
    @param children Function that renders the normal content *)
let make ~fallback children =
  (* Signal to track error state *)
  let state, set_state = Signal.create No_error in
  
  (* Attempt counter to force re-render on reset *)
  let attempt = ref 0 in
  
  (* Reset function clears error and increments attempt *)
  let reset () =
    incr attempt;
    ignore (set_state No_error)
  in
  
  (* Create memo that handles rendering *)
  let content = Memo.create (fun () ->
    match Signal.get state with
    | Has_error msg ->
      (* In error state - render fallback *)
      fallback ~error:msg ~reset
    | No_error ->
      (* Try to render children *)
      let _ = !attempt in (* Force dependency on attempt for re-render *)
      let handle_error exn =
        let msg = Printexc.to_string exn in
        ignore (set_state (Has_error msg))
      in
      try
        Reactive.with_error_handler handle_error children
      with exn ->
        let msg = Printexc.to_string exn in
        ignore (set_state (Has_error msg));
        fallback ~error:msg ~reset
  ) in
  Memo.get content

(** Simpler error boundary without reset capability.
    
    @param fallback Function that renders error state (receives error message)
    @param children Function that renders the normal content *)
let make_simple ~fallback children =
  try
    children ()
  with exn ->
    let msg = Printexc.to_string exn in
    fallback msg

module Unsafe = struct
  let make ~fallback children =
    let state, set_state = Signal.Unsafe.create No_error in

    let attempt = ref 0 in

    let reset () =
      incr attempt;
      ignore (set_state No_error)
    in

    let content = Memo.Unsafe.create (fun () ->
      match Signal.Unsafe.get state with
    | Has_error msg ->
      fallback ~error:msg ~reset
    | No_error ->
      let _ = !attempt in
      let handle_error exn =
        let msg = Printexc.to_string exn in
        ignore (set_state (Has_error msg))
      in
      try
        Reactive.with_error_handler handle_error children
      with exn ->
        let msg = Printexc.to_string exn in
        ignore (set_state (Has_error msg));
        fallback ~error:msg ~reset
    ) in
    Memo.Unsafe.get content

  let make_simple = make_simple
end
