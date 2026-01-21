(** Memoized derived values with automatic dependency tracking.
    
    Memos are computed values that cache their result and only
    recompute when their dependencies change. Like SolidJS, memos
    are eager - they compute immediately on creation.
*)

(** A memo is a computation that can be read like a signal *)
type 'a t = 'a Reactive.memo

type token = Runtime.token

(** Read a memo's value, tracking the dependency. *)
let get = Reactive.read_memo

(** Create a memoized value with optional custom equality. *)
let create (_token : token) ?equals fn =
  Reactive.create_memo ?equals fn

(** Create a memo with a custom equality function *)
let create_with_equals token ~eq fn = create token ~equals:eq fn

module Unsafe = struct
  let create ?equals fn = Reactive.create_memo ?equals fn
  let create_with_equals ~eq fn = create ~equals:eq fn
  let get = Reactive.read_memo
  let peek = Reactive.peek_memo
end

(** Read memo without tracking (peek at cached value). *)
let peek = Reactive.peek_memo
