(** Async primitive for Promise-based data fetching with Suspense integration.
    
    This module provides [create_async], a convenient wrapper for fetching async
    data that integrates seamlessly with Suspense boundaries. It's inspired by
    SolidJS's createAsync from solid-router.
    
    Key features:
    - Tracks reactive dependencies in the fetcher function
    - Auto-refetches when dependencies change
    - Integrates with Suspense (triggers fallback while loading)
    - Memoizes the result until dependencies change
    
    Usage:
    {[
      (* Simple async fetch *)
      let user = Async.create (fun () ->
        Fetch.get ("/api/users/" ^ Signal.get user_id)
      ) in
      
      (* In a Suspense boundary *)
      Suspense.boundary
        ~fallback:(fun () -> Html.text "Loading user...")
        (fun () ->
          let data = Async.get user in  (* Suspends if loading *)
          User_card.make ~user:data ()
        )
    ]}
*)

(** {1 Types} *)

(** The internal state of an async value *)
type 'a state =
  | Pending
  | Ready of 'a
  | Error of exn

(** An async value that tracks a Promise-returning function *)
type 'a t = {
  state : 'a state Reactive_core.signal;
  refetch : unit -> unit;
  id : int;
}

(** Unique ID counter for Suspense tracking *)
let next_id = ref 0

(** {1 Creation} *)

(** Create an async value from a Promise-returning function.
    
    The function is immediately called and will be re-called whenever any
    signals read inside it change (like createMemo with async support).
    
    @param fetcher A function that returns a Promise
    @return An async value that can be read with [get] *)
let create (fetcher : unit -> 'a Dom.promise) : 'a t =
  let state = Reactive_core.create_signal Pending in
  let id = !next_id in
  incr next_id;
  
  (* Track whether we're currently fetching to avoid duplicate requests *)
  let fetch_counter = ref 0 in
  
  let do_fetch () =
    (* Increment counter to identify this fetch request *)
    incr fetch_counter;
    let this_fetch = !fetch_counter in
    
    (* Set to pending *)
    Reactive_core.set_signal state Pending;
    
    (* Call the fetcher - this tracks dependencies *)
    let promise = fetcher () in
    
    (* Handle the promise *)
    Dom.promise_on_complete promise
      ~on_success:(fun data ->
        (* Only update if this is still the latest fetch *)
        if this_fetch = !fetch_counter then
          Reactive_core.set_signal state (Ready data)
      )
      ~on_error:(fun exn ->
        if this_fetch = !fetch_counter then
          Reactive_core.set_signal state (Error exn)
      )
  in
  
  (* Create an effect that re-runs the fetcher when dependencies change *)
  Reactive_core.create_effect (fun () ->
    do_fetch ()
  );
  
  { state; refetch = do_fetch; id }

(** Create an async value with a source signal.
    
    The fetcher is called whenever the source changes. This is useful when
    you want explicit control over the reactive dependency.
    
    @param source Signal that triggers refetch when changed
    @param fetcher Function that takes the source value and returns a Promise *)
let create_with_source (source : 'a Reactive_core.signal) (fetcher : 'a -> 'b Dom.promise) : 'b t =
  create (fun () ->
    let value = Reactive_core.get_signal source in
    fetcher value
  )

(** Create an async value that fetches once (no reactivity).
    
    Use this when you have a fixed fetch that shouldn't refetch on signal changes. *)
let create_once (fetcher : unit -> 'a Dom.promise) : 'a t =
  let state = Reactive_core.create_signal Pending in
  let id = !next_id in
  incr next_id;
  
  let do_fetch () =
    Reactive_core.set_signal state Pending;
    let promise = fetcher () in
    Dom.promise_on_complete promise
      ~on_success:(fun data -> Reactive_core.set_signal state (Ready data))
      ~on_error:(fun exn -> Reactive_core.set_signal state (Error exn))
  in
  
  (* Fetch immediately, but only once *)
  do_fetch ();
  
  { state; refetch = do_fetch; id }

(** {1 Reading} *)

(** Get the value, integrating with Suspense.
    
    - If Ready: returns the value
    - If Pending: registers with Suspense and raises a "Pending" exception
    - If Error: re-raises the error
    
    This function is designed to be used inside Suspense boundaries.
    The Suspense boundary will catch the suspension and show the fallback.
    
    @raise Failure if pending (caught by Suspense) or if an error occurred *)
let get (async : 'a t) : 'a =
  match Reactive_core.get_signal async.state with
  | Ready data -> data
  | Error exn -> raise exn
  | Pending ->
    (* Register with Suspense if available *)
    (match Suspense.get_state () with
     | Some suspense_state -> Suspense.increment suspense_state
     | None -> ()
    );
    (* Raise to signal that we're still loading *)
    failwith "Async value is pending"

(** Get the value with a default for pending state.
    
    Unlike [get], this doesn't raise when pending - it returns the default.
    Errors still raise.
    
    @param default Value to return while pending *)
let get_or (async : 'a t) ~(default : 'a) : 'a =
  match Reactive_core.get_signal async.state with
  | Ready data -> data
  | Error exn -> raise exn
  | Pending ->
    (* Register with Suspense if available *)
    (match Suspense.get_state () with
     | Some suspense_state -> Suspense.increment suspense_state
     | None -> ()
    );
    default

(** Get the current state without raising.
    
    This is useful when you want to handle all states explicitly. *)
let read (async : 'a t) : 'a state =
  Reactive_core.get_signal async.state

(** Peek at the state without tracking dependencies *)
let peek (async : 'a t) : 'a state =
  Reactive_core.peek_signal async.state

(** {1 State Inspection} *)

(** Check if the async value is still pending *)
let is_pending (async : 'a t) : bool =
  match peek async with Pending -> true | _ -> false

(** Check if the async value is ready *)
let is_ready (async : 'a t) : bool =
  match peek async with Ready _ -> true | _ -> false

(** Check if the async value has an error *)
let is_error (async : 'a t) : bool =
  match peek async with Error _ -> true | _ -> false

(** Get the data if ready *)
let data (async : 'a t) : 'a option =
  match peek async with Ready data -> Some data | _ -> None

(** Get the error if errored *)
let error (async : 'a t) : exn option =
  match peek async with Error exn -> Some exn | _ -> None

(** {1 Refetching} *)

(** Manually trigger a refetch *)
let refetch (async : 'a t) : unit =
  async.refetch ()

(** {1 Transformations} *)

(** Map over a ready value.
    
    The mapping is applied lazily when read. *)
let map (f : 'a -> 'b) (async : 'a t) : 'b state =
  match Reactive_core.get_signal async.state with
  | Ready data -> Ready (f data)
  | Pending -> Pending
  | Error exn -> Error exn

(** {1 Combinators} *)

(** Combine two async values.
    
    Returns Ready only when both are ready. *)
let both (a : 'a t) (b : 'b t) : ('a * 'b) state =
  match Reactive_core.get_signal a.state, Reactive_core.get_signal b.state with
  | Ready x, Ready y -> Ready (x, y)
  | Error e, _ | _, Error e -> Error e
  | Pending, _ | _, Pending -> Pending

(** Combine a list of async values.
    
    Returns Ready only when all are ready. *)
let all (asyncs : 'a t list) : 'a list state =
  let rec collect acc = function
    | [] -> Ready (List.rev acc)
    | a :: rest ->
      match Reactive_core.get_signal a.state with
      | Ready data -> collect (data :: acc) rest
      | Error e -> Error e
      | Pending -> Pending
  in
  collect [] asyncs

(** {1 Rendering Helpers} *)

(** Render based on async state *)
let render
    ~(pending : unit -> Html.node)
    ~(error : exn -> Html.node)
    ~(ready : 'a -> Html.node)
    (async : 'a t) : Html.node =
  match Reactive_core.get_signal async.state with
  | Pending -> pending ()
  | Error exn -> error exn
  | Ready data -> ready data

(** Render with default pending and error handlers *)
let render_simple ~(ready : 'a -> Html.node) (async : 'a t) : Html.node =
  render
    ~pending:(fun () -> Html.text "Loading...")
    ~error:(fun exn -> Html.p ~children:[Html.text ("Error: " ^ Dom.exn_to_string exn)] ())
    ~ready
    async

(** {1 Effect Integration} *)

(** Create an effect that runs when the async value becomes ready *)
let on_ready (async : 'a t) (callback : 'a -> unit) : unit =
  Reactive_core.create_effect (fun () ->
    match Reactive_core.get_signal async.state with
    | Ready data -> callback data
    | _ -> ()
  )

(** Create an effect that runs when the async value errors *)
let on_error (async : 'a t) (callback : exn -> unit) : unit =
  Reactive_core.create_effect (fun () ->
    match Reactive_core.get_signal async.state with
    | Error exn -> callback exn
    | _ -> ()
  )
