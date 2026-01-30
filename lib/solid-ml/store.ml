(** Reactive store for nested state management.
    
    Stores wrap a single reactive value with change tracking.
    For nested reactivity, combine with signals or use the produce utility.
    
    Matches SolidJS createStore API pattern:
    - create: wraps an initial value
    - produce: batch multiple updates
    - reconcile: merge external data
    
    Usage:
      let store = Store.create { user = { name = John; age = 30 } } in
      let name = Store.get store.user.name;  (* Simple access *)
      Store.set store { user = { name = Jane; age = 31 } };  (* Full replacement *)
    
    For fine-grained nested updates, combine with signals:
      let user_name, set_name = Signal.create "John" in
      Effect.create (fun () -> Store.get store.user.name <- Signal.get user_name)
 *)

(** {1 Types} *)

type 'a t = {
  value : 'a Signal.t;
  set_value : 'a -> unit;
}

type ('a, 'b) setter = 'a t -> 'b -> unit

(** {1 Store Creation} *)

let create (initial : 'a) : 'a t =
  let signal, set = Signal.create initial in
  { value = signal; set_value = set }

module Unsafe = struct
  let create (initial : 'a) : 'a t =
    let signal, set = Signal.Unsafe.create initial in
    { value = signal; set_value = set }

  let get (store : 'a t) : 'a =
    Signal.Unsafe.get store.value

  let peek (store : 'a t) : 'a =
    Signal.Unsafe.peek store.value

  let set (store : 'a t) (value : 'a) : unit =
    store.set_value value

  let update (store : 'a t) (fn : 'a -> 'a) : unit =
    store.set_value (fn (Signal.Unsafe.get store.value))
end

(** {1 Reading} *)

let get (store : 'a t) : 'a =
  Signal.get store.value

let peek (store : 'a t) : 'a =
  Signal.peek store.value

(** {1 Updating} *)

let set (store : 'a t) (value : 'a) : unit =
  store.set_value value

let update (store : 'a t) (fn : 'a -> 'a) : unit =
  store.set_value (fn (Signal.get store.value))

(** {1 Produce Utility} *)

let produce (fn : 'a -> unit) : ('a t -> 'a) =
  fun store ->
    fn (Signal.get store.value);
    Signal.get store.value

(** {1 Reconcile Utility} *)

let reconcile (data : 'a) : ('a t -> 'a) =
  fun store ->
    store.set_value data;
    data
