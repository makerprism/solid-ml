(** Token-bound helpers for strict APIs.

    This module provides a scoped API that binds a strict token once and
    exposes token-free helpers for Signal, Effect, Memo, Batch, and Owner.
*)

type token = Runtime.token

module type S = sig
  module Signal : sig
    type 'a t

    val create : ?equals:('a -> 'a -> bool) -> 'a -> 'a t * ('a -> unit)
    val create_eq : equals:('a -> 'a -> bool) -> 'a -> 'a t * ('a -> unit)
    val create_physical : 'a -> 'a t * ('a -> unit)
    val get : 'a t -> 'a
    val set : 'a t -> 'a -> unit
    val update : 'a t -> ('a -> 'a) -> unit
    val peek : 'a t -> 'a
    val subscribe : 'a t -> (unit -> unit) -> (unit -> unit)
  end

  module Memo : sig
    type 'a t

    val create : ?equals:('a -> 'a -> bool) -> (unit -> 'a) -> 'a t
    val create_with_equals : eq:('a -> 'a -> bool) -> (unit -> 'a) -> 'a t
    val get : 'a t -> 'a
    val peek : 'a t -> 'a
  end

  module Effect : sig
    val create : (unit -> unit) -> unit
    val create_with_cleanup : (unit -> (unit -> unit)) -> unit
    val create_deferred : track:(unit -> 'a) -> run:('a -> unit) -> unit
    val untrack : (unit -> 'a) -> 'a
    val on : ?defer:bool -> (unit -> 'a) -> (value:'a -> prev:'a -> unit) -> unit
  end

  module Batch : sig
    val run : (unit -> 'a) -> 'a
    val is_batching : unit -> bool
  end

  module Owner : sig
    val create_root : (unit -> unit) -> (unit -> unit)
    val run_with_owner : (unit -> 'a) -> 'a * (unit -> unit)
    val on_cleanup : (unit -> unit) -> unit
    val get_owner : unit -> Runtime.owner option
    val catch_error : (unit -> 'a) -> (exn -> 'a) -> 'a
  end
end

(** Create a token-bound API for the given token. *)
val with_token : token -> ((module S) -> 'a) -> 'a

(** Run a function within a new runtime with token-bound helpers. *)
val run : ((module S) -> 'a) -> 'a
