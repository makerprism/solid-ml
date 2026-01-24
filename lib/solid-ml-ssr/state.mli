(** Server-side state serialization for hydration.

    This module provides functions to serialize application state that
    will be transferred to the client for hydration.

    The state is stored in Domain-Local Storage (DLS) so each request
    handler has its own isolated state table.

    {[
      (* In your request handler *)
      let () =
        (* Store state for client *)
        State.set_encoded ~key:"user_id" ~encode:State.encode_int 42;
        State.set_encoded
          ~key:"user"
          ~encode:(fun u -> State.encode_object [...])
          { name = "Alice"; id = 42 };

        (* Render your component *)
        let html = Render.to_document my_app in

        (* Get the state script tag *)
        let script = Render.get_hydration_script () in

        (* Include both in your response *)
        html ^ script
    ]}

    On the client, use [Solid_ml_browser.State.decode] to retrieve
    the serialized state.
*)

type json = string
(** JSON type - represented as string on server side *)

(** {1 Keys} *)

val key : ?namespace:string -> string -> string
(** [key ~namespace name] creates a namespaced key for state storage.

    Use namespaces to avoid conflicts between different parts of your app.

    {[
      let k1 = State.key ~namespace:"app" "counter"  (* "app:counter" *)
      let k2 = State.key "user"                      (* "user" *)
    ]}
*)

(** {1 Managing State} *)

val reset : unit -> unit
(** Reset the state table.

    Called automatically by [Render.to_string] and [Render.to_document].
    Call manually between renders if needed.
*)

val set : key:string -> json -> unit
(** [set ~key value] stores a pre-encoded JSON string.

    {[
      State.set ~key:"custom" "{\"value\":42}"
    ]}
*)

val set_encoded : key:string -> encode:('a -> json) -> 'a -> unit
(** [set_encoded ~key ~encode value] encodes and stores a value.

    {[
      State.set_encoded ~key:"count" ~encode:State.encode_int 42;
      State.set_encoded ~key:"name" ~encode:State.encode_string "Alice";
    ]}
*)

val get : key:string -> json option
(** [get ~key] retrieves the stored JSON string.

    Returns [None] if the key doesn't exist.
    Mainly useful for debugging and testing.
*)

(** {1 JSON Encoders} *)

val encode_string : string -> json
(** Encode a string to JSON (with escaping). *)

val encode_int : int -> json
(** Encode an int to JSON. *)

val encode_float : float -> json
(** Encode a float to JSON.

    Returns "null" for non-finite values (infinity, NaN).
*)

val encode_bool : bool -> json
(** Encode a bool to JSON ("true" or "false"). *)

val encode_null : json
(** JSON null value. *)

val encode_list : json list -> json
(** Encode a list of JSON values to a JSON array.

    {[
      State.encode_list [State.encode_int 1; State.encode_int 2; State.encode_int 3]
      (* "[1,2,3]" *)
    ]}
*)

val encode_object : (string * json) list -> json
(** Encode key-value pairs to a JSON object.

    {[
      State.encode_object [
        ("name", State.encode_string "Alice");
        ("age", State.encode_int 30);
        ("admin", State.encode_bool true);
      ]
      (* {"name":"Alice","age":30,"admin":true} *)
    ]}
*)

(** {1 Resource State Encoders}

    These encoders create the standard resource state format used by
    the Solid_ml_browser.Resource and Async modules.
*)

val encode_resource_ready : json -> json
(** Encode a resource in the "ready" state.

    {[
      State.encode_resource_ready (State.encode_string "data")
      (* {"status":"ready","data":"data"} *)
    ]}
*)

val encode_resource_error : string -> json
(** Encode a resource in the "error" state.

    {[
      State.encode_resource_error "Something went wrong"
      (* {"status":"error","error":"Something went wrong"} *)
    ]}
*)

val encode_resource_loading : unit -> json
(** Encode a resource in the "loading" state.

    {[
      State.encode_resource_loading ()
      (* {"status":"loading"} *)
    ]}
*)

(** {1 Serialization} *)

val to_json : unit -> json
(** [to_json ()] serializes all stored state to a JSON object string.

    {[
      (* After storing some state *)
      State.set_encoded ~key:"count" ~encode:State.encode_int 42;

      (* Get complete JSON object *)
      let json = State.to_json ()
      (* {"count":42} *)
    ]}
*)

val to_script : unit -> string
(** [to_script ()] generates the script tag for embedding in HTML.

    Creates: [<script>window.__SOLID_ML_DATA__ = {...};</script>]

    {[
      let html = Render.to_document my_app in
      let script = State.to_script () in
      html ^ script  (* Include in response *)
    ]}

    Note: [Render.get_hydration_script] already includes this,
    along with event replay scripts.
*)
