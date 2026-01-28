(** Store module for nested reactive state with lens-based updates.
    
    This module provides a type-safe alternative to SolidJS's createStore
    using functional lenses for accessing and updating nested state.
    
    Instead of path-based string accessors like:
    {[
      setStore("users", 0, "loggedIn", true)  // SolidJS
    ]}
    
    We use composable lenses:
    {[
      Store.set store (users |-- nth 0 |-- logged_in) true  // solid-ml
    ]}
    
    Key features:
    - Type-safe nested access via lenses
    - Fine-grained reactivity (only affected paths trigger updates)
    - Immutable updates with structural sharing
    - Composable lens combinators
    
    Usage:
    {[
      (* Define your state type *)
      type user = { name: string; age: int }
      type state = { users: user list; count: int }
      
      (* Create lenses (can be auto-generated with ppx_lens) *)
      let users = Lens.make (fun s -> s.users) (fun s v -> { s with users = v })
      let count = Lens.make (fun s -> s.count) (fun s v -> { s with count = v })
      let name = Lens.make (fun u -> u.name) (fun u v -> { u with name = v })
      let age = Lens.make (fun u -> u.age) (fun u v -> { u with age = v })
      
      (* Create a store *)
      let store = Store.create { users = []; count = 0 }
      
      (* Read values *)
      let current_count = Store.get store count
      
      (* Update values *)
      Store.set store count 5
      Store.update store count (fun c -> c + 1)
      
      (* Compose lenses for nested access *)
      Store.set store (users |-- Lens.nth 0 |-- name) "Alice"
    ]}
*)

(** {1 Lens Type and Operations} *)

(** A lens focuses on a part of a larger structure.
    'a is the whole type, 'b is the focused part. *)
type ('a, 'b) lens = {
  get: 'a -> 'b;
  set: 'a -> 'b -> 'a;
}

(** Module for lens operations and combinators *)
module Lens = struct
  (** Create a lens from getter and setter functions *)
  let make ~get ~set = { get; set }
  
  (** Identity lens - focuses on the whole *)
  let id : ('a, 'a) lens = {
    get = Fun.id;
    set = (fun _ x -> x);
  }
  
  (** Compose two lenses: focus through first, then second *)
  let compose (outer : ('a, 'b) lens) (inner : ('b, 'c) lens) : ('a, 'c) lens = {
    get = (fun a -> inner.get (outer.get a));
    set = (fun a c -> 
      let b = outer.get a in
      let b' = inner.set b c in
      outer.set a b'
    );
  }
  
  (** Infix compose operator: (outer |-- inner) *)
  let ( |-- ) = compose
  
  (** Get value through lens *)
  let get lens x = lens.get x
  
  (** Set value through lens *)
  let set lens x v = lens.set x v
  
  (** Update value through lens with a function *)
  let update lens x f = lens.set x (f (lens.get x))
  
  (** {2 List Lenses} *)
  
  (** Lens to nth element of a list.
      Raises if index out of bounds during set. *)
  let nth (n : int) : ('a list, 'a) lens = {
    get = (fun xs -> List.nth xs n);
    set = (fun xs v -> List.mapi (fun i x -> if i = n then v else x) xs);
  }
  
  (** Lens to head of a list.
      Raises on empty list. *)
  let head : ('a list, 'a) lens = {
    get = List.hd;
    set = (fun xs v -> match xs with [] -> [v] | _ :: rest -> v :: rest);
  }
  
  (** Lens to tail of a list.
      Raises on empty list. *)
  let tail : ('a list, 'a list) lens = {
    get = List.tl;
    set = (fun xs v -> match xs with [] -> v | h :: _ -> h :: v);
  }
  
  (** Safe lens to nth element, returning option *)
  let nth_opt (n : int) : ('a list, 'a option) lens = {
    get = (fun xs -> List.nth_opt xs n);
    set = (fun xs v_opt ->
      match v_opt with
      | None -> xs  (* No change if None *)
      | Some v -> List.mapi (fun i x -> if i = n then v else x) xs
    );
  }
  
  (** {2 Option Lenses} *)
  
  (** Lens into Some value.
      Get returns the inner value or raises.
      Set wraps in Some. *)
  let some : ('a option, 'a) lens = {
    get = (function Some x -> x | None -> failwith "Lens.some: got None");
    set = (fun _ v -> Some v);
  }
  
  (** Safe lens that provides default for None *)
  let with_default (default : 'a) : ('a option, 'a) lens = {
    get = (function Some x -> x | None -> default);
    set = (fun _ v -> Some v);
  }
  
  (** {2 Tuple Lenses} *)
  
  (** First element of a pair *)
  let fst : ('a * 'b, 'a) lens = {
    get = Stdlib.fst;
    set = (fun (_, b) a -> (a, b));
  }
  
  (** Second element of a pair *)
  let snd : ('a * 'b, 'b) lens = {
    get = Stdlib.snd;
    set = (fun (a, _) b -> (a, b));
  }
  
  (** {2 Array Lenses} *)
  
  (** Lens to array element at index.
      Creates a new array on set (immutable semantics). *)
  let array_nth (n : int) : ('a array, 'a) lens = {
    get = (fun arr -> arr.(n));
    set = (fun arr v ->
      let arr' = Array.copy arr in
      arr'.(n) <- v;
      arr'
    );
  }
end

(** {1 Store Type} *)

(** A store holds reactive state with lens-based access.
    
    The store tracks a version number that increments on every update,
    which can be useful for debugging or cache invalidation. *)
type 'a t = {
  state: 'a Reactive_core.signal;
  version: int ref;
}

(** {1 Creation} *)

(** Create a new store with initial state *)
let create (initial : 'a) : 'a t = {
  state = Reactive_core.create_signal initial;
  version = ref 0;
}

(** {1 Reading State} *)

(** Get the entire state (reactive - triggers updates) *)
let get_all (store : 'a t) : 'a =
  Reactive_core.get_signal store.state

(** Get a focused value through a lens (reactive) *)
let get (store : 'a t) (lens : ('a, 'b) lens) : 'b =
  lens.get (Reactive_core.get_signal store.state)

(** Peek at the entire state (non-reactive) *)
let peek_all (store : 'a t) : 'a =
  Reactive_core.peek_signal store.state

(** Peek at a focused value (non-reactive) *)
let peek (store : 'a t) (lens : ('a, 'b) lens) : 'b =
  lens.get (Reactive_core.peek_signal store.state)

(** Get the current version number.
    
    The version increments on every update to the store.
    This is useful for debugging or as a cache invalidation key. *)
let version (store : 'a t) : int =
  !(store.version)

(** {1 Updating State} *)

(** Set the entire state *)
let set_all (store : 'a t) (value : 'a) : unit =
  incr store.version;
  ignore (Reactive_core.set_signal store.state value)

(** Set a focused value through a lens *)
let set (store : 'a t) (lens : ('a, 'b) lens) (value : 'b) : unit =
  incr store.version;
  let current = Reactive_core.peek_signal store.state in
  let updated = lens.set current value in
  ignore (Reactive_core.set_signal store.state updated)

(** Update a focused value with a function *)
let update (store : 'a t) (lens : ('a, 'b) lens) (f : 'b -> 'b) : unit =
  incr store.version;
  let current = Reactive_core.peek_signal store.state in
  let updated = Lens.update lens current f in
  ignore (Reactive_core.set_signal store.state updated)

(** Update the entire state with a function *)
let update_all (store : 'a t) (f : 'a -> 'a) : unit =
  incr store.version;
  ignore (Reactive_core.update_signal store.state f)

(** {1 Batch Updates} *)

(** Run multiple updates as a batch (single reactive update) *)
let batch (f : unit -> unit) : unit =
  Reactive_core.batch f

(** {1 Derived State} *)

(** Create a derived memo from a lens.
    
    This creates a memo that extracts a portion of the store and only
    updates when that portion changes. *)
let derive (store : 'a t) (lens : ('a, 'b) lens) : 'b Reactive_core.memo =
  Reactive_core.create_memo (fun () -> get store lens)

(** Create a derived memo with custom equality *)
let derive_with_equals
    (store : 'a t)
    (lens : ('a, 'b) lens)
    ~(equals : 'b -> 'b -> bool)
    : 'b Reactive_core.memo =
  Reactive_core.create_memo ~equals (fun () -> get store lens)

(** {1 List Operations} *)

(** Append an item to a list field *)
let push (store : 'a t) (lens : ('a, 'b list) lens) (item : 'b) : unit =
  update store lens (fun xs -> xs @ [item])

(** Prepend an item to a list field *)
let unshift (store : 'a t) (lens : ('a, 'b list) lens) (item : 'b) : unit =
  update store lens (fun xs -> item :: xs)

(** Remove items matching a predicate from a list field *)
let filter (store : 'a t) (lens : ('a, 'b list) lens) (pred : 'b -> bool) : unit =
  update store lens (List.filter pred)

(** Map over a list field *)
let map_list (store : 'a t) (lens : ('a, 'b list) lens) (f : 'b -> 'b) : unit =
  update store lens (List.map f)

(** Find and update first matching item in a list *)
let find_update
    (store : 'a t)
    (lens : ('a, 'b list) lens)
    ~(find : 'b -> bool)
    ~(f : 'b -> 'b)
    : unit =
  let rec update_first = function
    | [] -> []
    | x :: xs when find x -> f x :: xs
    | x :: xs -> x :: update_first xs
  in
  update store lens update_first

(** {1 Effect Integration} *)

(** Create an effect that watches a focused value *)
let on_change (store : 'a t) (lens : ('a, 'b) lens) (callback : 'b -> unit) : unit =
  Reactive_core.create_effect (fun () ->
    let value = get store lens in
    callback value
  )

(** Create an effect that watches the entire store *)
let on_change_all (store : 'a t) (callback : 'a -> unit) : unit =
  Reactive_core.create_effect (fun () ->
    let value = get_all store in
    callback value
  )

(** {1 Subscriptions} *)

(** Subscribe to changes in a focused value.
    Returns an unsubscribe function.
    
    The callback is invoked immediately with the current value, and then
    again whenever the focused value changes.
    
    Note: The underlying effect exists until the owning reactive root is disposed.
    Calling unsubscribe stops the callback from being invoked but doesn't
    fully dispose the effect (this matches SolidJS behavior). *)
let subscribe (store : 'a t) (lens : ('a, 'b) lens) (callback : 'b -> unit) : (unit -> unit) =
  let active = ref true in
  Reactive_core.create_effect_with_cleanup (fun () ->
    if !active then begin
      let value = get store lens in
      callback value
    end;
    (* Cleanup function - called before next run and on owner disposal *)
    fun () -> ()
  );
  (* Return unsubscribe function *)
  fun () -> active := false

(** {1 Produce (Immer-style updates)} *)

(** Apply a "producer" function that mutates a draft.
    
    This is NOT actually mutable - it works by:
    1. Getting current state
    2. Passing to producer which returns new state
    3. Setting the new state
    
    It provides an Immer-like API for users familiar with that pattern.
    The producer function should return the modified state.
    
    {[
      Store.produce store (fun state ->
        { state with count = state.count + 1 }
      )
    ]}
*)
let produce (store : 'a t) (producer : 'a -> 'a) : unit =
  update_all store producer

(** Produce a focused value *)
let produce_at (store : 'a t) (lens : ('a, 'b) lens) (producer : 'b -> 'b) : unit =
  update store lens producer

(** {1 Reconcile} *)

(** Reconcile a list by key.
    
    Updates existing items, adds new ones, removes missing ones.
    Similar to SolidJS's reconcile function for arrays.
    
    @param get_key Function to extract unique key from items
    @param merge Function to merge old item with new data *)
let reconcile
    (store : 'a t)
    (lens : ('a, 'b list) lens)
    ~(get_key : 'b -> string)
    ~(merge : 'b -> 'b -> 'b)
    (new_items : 'b list)
    : unit =
  update store lens (fun old_items ->
    (* Build map of old items by key *)
    let old_map = Hashtbl.create (List.length old_items) in
    List.iter (fun item -> Hashtbl.add old_map (get_key item) item) old_items;
    
    (* Merge or add new items *)
    List.map (fun new_item ->
      let key = get_key new_item in
      match Hashtbl.find_opt old_map key with
      | Some old_item -> merge old_item new_item
      | None -> new_item
    ) new_items
  )

(** Simple reconcile that replaces items by key *)
let reconcile_replace
    (store : 'a t)
    (lens : ('a, 'b list) lens)
    ~(get_key : 'b -> string)
    (new_items : 'b list)
    : unit =
  reconcile store lens ~get_key ~merge:(fun _ new_item -> new_item) new_items

(** {1 Store Slices} *)

(** A slice is a store-like view into a portion of a parent store *)
type ('parent, 'child) slice = {
  parent: 'parent t;
  lens: ('parent, 'child) lens;
}

(** Create a slice of a store focused through a lens *)
let slice (store : 'a t) (lens : ('a, 'b) lens) : ('a, 'b) slice =
  { parent = store; lens }

(** Get from a slice *)
let slice_get (s : ('a, 'b) slice) : 'b =
  get s.parent s.lens

(** Set through a slice *)
let slice_set (s : ('a, 'b) slice) (value : 'b) : unit =
  set s.parent s.lens value

(** Update through a slice *)
let slice_update (s : ('a, 'b) slice) (f : 'b -> 'b) : unit =
  update s.parent s.lens f

(** Compose a slice with another lens *)
let slice_compose (s : ('a, 'b) slice) (inner : ('b, 'c) lens) : ('a, 'c) slice =
  { parent = s.parent; lens = Lens.compose s.lens inner }

(** Infix for composing slice with lens *)
let ( |-> ) = slice_compose
