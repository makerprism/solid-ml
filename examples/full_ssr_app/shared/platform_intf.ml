(** Shared interface for Reactive Components 
    
    This module type defines the interface that our shared components will use.
    It abstracts away the differences between server (solid-ml-ssr) and 
    browser (solid-ml-browser) implementations.
*)

module type S = sig
  (** The reactive primitives *)
  module Signal : sig
    type 'a t
    val create : 'a -> 'a t * ('a -> unit)
    val get : 'a t -> 'a
    val set : 'a t -> 'a -> unit
    val update : 'a t -> ('a -> 'a) -> unit
    val peek : 'a t -> 'a
  end

  module Memo : sig
    type 'a t
    val create : (unit -> 'a) -> 'a t
    val get : 'a t -> 'a
    val as_signal : 'a t -> 'a Signal.t (* Helper *)
  end

  module Effect : sig
    val create : (unit -> unit) -> unit
  end
  
  (** HTML Element generation *)
  module Html : sig
    type node
    type event

    val text : string -> node
    val int : int -> node
    val float : float -> node
    val reactive_text : int Signal.t -> node
    val reactive_text_string : string Signal.t -> node
    val fragment : node list -> node

    val div : ?id:string -> ?class_:string -> ?onclick:(event -> unit) -> children:node list -> unit -> node
    val span : ?id:string -> ?class_:string -> ?children:node list -> unit -> node
    val p : ?children:node list -> unit -> node
    val h1 : ?children:node list -> unit -> node
    val h2 : ?children:node list -> unit -> node
    val button : ?id:string -> ?class_:string -> ?onclick:(event -> unit) -> children:node list -> unit -> node
    val input : ?type_:string -> ?checked:bool -> ?oninput:(event -> unit) -> ?onchange:(event -> unit) -> unit -> node
    val ul : ?id:string -> ?class_:string -> ?children:node list -> unit -> node
    val li : ?id:string -> ?class_:string -> ?children:node list -> unit -> node
    val a : ?href:string -> ?class_:string -> ?onclick:(event -> unit) -> children:node list -> unit -> node
    
    (** Helper for preventing default event action *)
    val prevent_default : event -> unit
  end

  (** Reactive list rendering *)
  module For : sig
    val list : 'a list Signal.t -> ('a -> Html.node) -> Html.node
  end

  module Router : sig
    val use_path : unit -> string
    val use_params : unit -> (string * string) list
    val use_query_param : string -> string option
    val navigate : string -> unit
    
    (* Components *)
    val link : href:string -> ?class_:string -> children:Html.node list -> unit -> Html.node
  end
end
