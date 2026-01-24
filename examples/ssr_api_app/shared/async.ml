module type S = sig
  type 'a t

  val return : 'a -> 'a t
  val bind : 'a t -> ('a -> 'b t) -> 'b t
  val map : ('a -> 'b) -> 'a t -> 'b t
  val fail : Error.t -> 'a t
  val catch : (unit -> 'a t) -> (Error.t -> 'a t) -> 'a t
  val run : 'a t -> ok:('a -> unit) -> err:(Error.t -> unit) -> unit
  val make : (ok:('a -> unit) -> err:(Error.t -> unit) -> unit) -> 'a t
end

type 'a t = ok:('a -> unit) -> err:(Error.t -> unit) -> unit

let make f = f

let return value ~ok ~err:_ = ok value

let fail error ~ok:_ ~err = err error

let bind value f ~ok ~err =
  value
    ~ok:(fun v -> f v ~ok ~err)
    ~err

let map f value ~ok ~err =
  value
    ~ok:(fun v -> ok (f v))
    ~err

let catch thunk handler ~ok ~err =
  thunk ()
    ~ok
    ~err:(fun e -> handler e ~ok ~err)

let run value ~ok ~err =
  value ~ok ~err
