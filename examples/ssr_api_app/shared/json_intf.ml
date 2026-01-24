module type S = sig
  type t

  val parse : string -> (t, Error.t) Result.t
  val member : t -> string -> t option
  val to_int : t -> (int, Error.t) Result.t
  val to_string : t -> (string, Error.t) Result.t
  val to_list : t -> (t list, Error.t) Result.t
end
