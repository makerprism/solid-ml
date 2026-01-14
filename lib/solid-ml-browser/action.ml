(** Action module for handling mutations with cache revalidation.
    
    Actions are async functions designed for submitting data to the server.
    They track pending/result state and can trigger cache invalidation
    after successful mutations.
    
    Inspired by SolidJS's actions from solid-router.
    
    Usage:
    {[
      (* Define an action *)
      let save_user = Action.create (fun user_data ->
        Fetch.post "/api/users" user_data
      ) in
      
      (* Get a callable function *)
      let submit = Action.use save_user in
      
      (* Track submission state *)
      let submission = Action.use_submission save_user in
      
      (* In your component *)
      Html.(
        form ~onsubmit:(fun e ->
          Event.prevent_default e;
          submit form_data
        ) ~children:[
          (if Signal.get submission.pending
           then text "Saving..."
           else text "Save");
        ] ()
      )
    ]}
*)

(** {1 Types} *)

(** Submission state for tracking action progress *)
type 'a submission = {
  pending: bool Reactive_core.signal;
  result: 'a option Reactive_core.signal;
  error: exn option Reactive_core.signal;
  input: 'input option Reactive_core.signal;
  clear: unit -> unit;
}
  constraint 'a = 'output
  constraint 'input = _

(** Simplified submission type - tracks output only *)
type 'output submission_state = {
  s_pending: bool Reactive_core.signal;
  s_result: 'output option Reactive_core.signal;
  s_error: exn option Reactive_core.signal;
  s_clear: unit -> unit;
}

(** An action wraps an async mutation function *)
type ('input, 'output) t = {
  handler: 'input -> 'output Dom.promise;
  pending: bool Reactive_core.signal;
  result: 'output option Reactive_core.signal;
  error: exn option Reactive_core.signal;
  input: 'input option Reactive_core.signal;
  revalidation_keys: string list ref;
}

(** Registry for async resources that can be revalidated *)
module Registry = struct
  (** Map of key -> refetch function *)
  let resources : (string, unit -> unit) Hashtbl.t = Hashtbl.create 16
  
  (** Register a resource with a key for revalidation *)
  let register key refetch =
    Hashtbl.replace resources key refetch
  
  (** Unregister a resource *)
  let unregister key =
    Hashtbl.remove resources key
  
  (** Trigger revalidation for a specific key *)
  let revalidate_key key =
    match Hashtbl.find_opt resources key with
    | Some refetch -> refetch ()
    | None -> ()
  
  (** Trigger revalidation for all registered resources *)
  let revalidate_all () =
    Hashtbl.iter (fun _ refetch -> refetch ()) resources
  
  (** Clear all registrations *)
  let clear () =
    Hashtbl.clear resources
end

(** {1 Creation} *)

(** Create an action from an async handler function.
    
    @param handler Function that takes input and returns a Promise
    @return An action that can be used with [use] and [use_submission] *)
let create (handler : 'input -> 'output Dom.promise) : ('input, 'output) t =
  {
    handler;
    pending = Reactive_core.create_signal false;
    result = Reactive_core.create_signal None;
    error = Reactive_core.create_signal None;
    input = Reactive_core.create_signal None;
    revalidation_keys = ref [];
  }

(** Create an action that revalidates specific cache keys on success.
    
    @param keys List of cache keys to revalidate after successful mutation
    @param handler The async mutation function *)
let create_with_revalidation ~keys (handler : 'input -> 'output Dom.promise) : ('input, 'output) t =
  let action = create handler in
  action.revalidation_keys := keys;
  action

(** {1 Using Actions} *)

(** Get a callable function from an action.
    
    The returned function will:
    1. Set pending = true
    2. Clear previous result/error
    3. Execute the handler
    4. On success: set result, trigger revalidation
    5. On error: set error
    6. Set pending = false
    
    @param action The action to use
    @return A function that executes the action *)
let use (action : ('input, 'output) t) : ('input -> unit) =
  fun input ->
    (* Set pending state *)
    Reactive_core.set_signal action.pending true;
    Reactive_core.set_signal action.input (Some input);
    Reactive_core.set_signal action.error None;
    
    (* Execute the handler *)
    let promise = action.handler input in
    
    (* Handle completion *)
    Dom.promise_on_complete promise
      ~on_success:(fun output ->
        Reactive_core.set_signal action.result (Some output);
        Reactive_core.set_signal action.pending false;
        
        (* Trigger revalidation for registered keys *)
        List.iter Registry.revalidate_key !(action.revalidation_keys)
      )
      ~on_error:(fun exn ->
        Reactive_core.set_signal action.error (Some exn);
        Reactive_core.set_signal action.pending false
      )

(** Get a callable function that returns the Promise.
    
    Unlike [use], this returns the Promise so you can await it or chain it.
    
    @param action The action to use
    @return A function that executes the action and returns its Promise *)
let use_async (action : ('input, 'output) t) : ('input -> 'output Dom.promise) =
  fun input ->
    (* Set pending state *)
    Reactive_core.set_signal action.pending true;
    Reactive_core.set_signal action.input (Some input);
    Reactive_core.set_signal action.error None;
    
    (* Execute and wrap to track completion *)
    let promise = action.handler input in
    
    (* Create a wrapper promise that updates state *)
    Dom.promise_make (fun resolve reject ->
      Dom.promise_on_complete promise
        ~on_success:(fun output ->
          Reactive_core.set_signal action.result (Some output);
          Reactive_core.set_signal action.pending false;
          List.iter Registry.revalidate_key !(action.revalidation_keys);
          resolve output
        )
        ~on_error:(fun exn ->
          Reactive_core.set_signal action.error (Some exn);
          Reactive_core.set_signal action.pending false;
          reject exn
        )
    )

(** Track submission state for an action.
    
    Returns signals that update as the action executes:
    - [pending]: true while the action is running
    - [result]: Some output after success, None otherwise
    - [error]: Some exn after failure, None otherwise
    - [clear]: Function to reset result/error state
    
    @param action The action to track
    @return Submission state signals *)
let use_submission (action : ('input, 'output) t) : 'output submission_state =
  let clear () =
    Reactive_core.set_signal action.result None;
    Reactive_core.set_signal action.error None;
    Reactive_core.set_signal action.input None
  in
  {
    s_pending = action.pending;
    s_result = action.result;
    s_error = action.error;
    s_clear = clear;
  }

(** {1 Revalidation} *)

(** Register an Async resource for revalidation.
    
    Call this when creating an Async resource that should be refetched
    when related data is mutated.
    
    @param key Unique key for this resource
    @param async The Async.t to register *)
let register_async ~key (async : 'a Async.t) : unit =
  Registry.register key (fun () -> Async.refetch async)

(** Unregister a resource from revalidation *)
let unregister ~key : unit =
  Registry.unregister key

(** Manually trigger revalidation for a specific key.
    
    @param key The cache key to revalidate *)
let revalidate ~key : unit =
  Registry.revalidate_key key

(** Trigger revalidation for all registered resources *)
let revalidate_all () : unit =
  Registry.revalidate_all ()

(** {1 Action State Inspection} *)

(** Check if the action is currently pending *)
let is_pending (action : ('input, 'output) t) : bool =
  Reactive_core.peek_signal action.pending

(** Get the last successful result *)
let last_result (action : ('input, 'output) t) : 'output option =
  Reactive_core.peek_signal action.result

(** Get the last error *)
let last_error (action : ('input, 'output) t) : exn option =
  Reactive_core.peek_signal action.error

(** Get the last input *)
let last_input (action : ('input, 'output) t) : 'input option =
  Reactive_core.peek_signal action.input

(** Clear the action state (result, error, input) *)
let clear (action : ('input, 'output) t) : unit =
  Reactive_core.set_signal action.result None;
  Reactive_core.set_signal action.error None;
  Reactive_core.set_signal action.input None

(** {1 Convenience Functions} *)

(** Create and immediately use an action.
    
    Shorthand for creating an action and getting its callable.
    
    @param handler The async mutation function
    @return A callable function *)
let make (handler : 'input -> 'output Dom.promise) : ('input -> unit) =
  use (create handler)

(** Create an action that doesn't need input.
    
    @param handler An async function with no input
    @return An action that takes unit *)
let create_simple (handler : unit -> 'output Dom.promise) : (unit, 'output) t =
  create handler

(** {1 Composition} *)

(** Chain two actions: run the second after the first succeeds.
    
    @param first Action to run first
    @param second Function that takes first's output and returns second action's input
    @return A combined action *)
let chain
    (first : ('a, 'b) t)
    (second : 'b -> ('c, 'd) t)
    : ('a, 'd) t =
  create (fun input ->
    Dom.promise_make (fun resolve reject ->
      let first_promise = first.handler input in
      Dom.promise_on_complete first_promise
        ~on_success:(fun b ->
          let second_action = second b in
          let second_promise = second_action.handler b in
          Dom.promise_on_complete second_promise
            ~on_success:resolve
            ~on_error:reject
        )
        ~on_error:reject
    )
  )

(** Run an action with optimistic updates.
    
    This immediately updates the UI optimistically, then reverts if the action fails.
    
    @param action The action to run
    @param optimistic Function to apply optimistic update (returns rollback function)
    @return A wrapped callable that handles optimistic updates *)
let with_optimistic
    (action : ('input, 'output) t)
    ~(optimistic : 'input -> (unit -> unit))
    : ('input -> unit) =
  fun input ->
    (* Apply optimistic update, get rollback function *)
    let rollback = optimistic input in
    
    (* Execute the action *)
    let promise = action.handler input in
    
    (* Update state *)
    Reactive_core.set_signal action.pending true;
    Reactive_core.set_signal action.input (Some input);
    Reactive_core.set_signal action.error None;
    
    Dom.promise_on_complete promise
      ~on_success:(fun output ->
        Reactive_core.set_signal action.result (Some output);
        Reactive_core.set_signal action.pending false;
        List.iter Registry.revalidate_key !(action.revalidation_keys)
      )
      ~on_error:(fun exn ->
        (* Rollback on error *)
        rollback ();
        Reactive_core.set_signal action.error (Some exn);
        Reactive_core.set_signal action.pending false
      )

(** {1 Form Integration} *)

(** Create an action that extracts data from a form event.
    
    This is useful for form submissions where you want to extract
    form data and submit it.
    
    @param extract Function to extract data from form element
    @param handler Action handler that takes extracted data *)
let from_form
    ~(extract : Dom.element -> 'input)
    (handler : 'input -> 'output Dom.promise)
    : (Dom.event -> unit) =
  let action = create handler in
  let submit = use action in
  fun event ->
    Dom.prevent_default event;
    let target = Dom.event_target event in
    let element = Dom.element_of_event_target target in
    let data = extract element in
    submit data
