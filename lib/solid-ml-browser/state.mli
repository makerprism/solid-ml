(** Client-side state transfer for hydration.

    This module provides access to server state that has been serialized
    into the page via the [window.__SOLID_ML_DATA__] global variable.

    On the server side, use [Solid_ml_ssr.State] to set state values.
    Then use [Solid_ml_ssr.Render.get_hydration_script] to generate
    a script tag that embeds the state in the HTML.

    {[
      (* Server - see solid-ml-ssr/State *)
      let () =
        State.set_encoded ~key:"user_id" ~encode:State.encode_int 42;
        let html = Render.to_document my_app in
        let script = Render.get_hydration_script () in
        (* Include html ^ script in response *)

      (* Client - this module *)
      let user_id =
        State.decode
          ~key:"user_id"
          ~decode:(fun json -> Js.Json.decodeNumber json |> Option.map int_of_float)
          ~default:0
          ()
    ]}
*)

type json = Js.Json.t
(** JSON type - alias for Js.Json.t *)

(** {1 Keys} *)

val key : ?namespace:string -> string -> string
(** [key ~namespace name] creates a namespaced key for state storage.

    Use namespaces to avoid conflicts between different parts of your app.

    {[
      let k1 = State.key ~namespace:"app" "counter"  (* "app:counter" *)
      let k2 = State.key "user"                      (* "user" *)
    ]}
*)

(** {1 Reading State} *)

val get : key:string -> json option
(** [get ~key] retrieves raw JSON state from window.__SOLID_ML_DATA__.

    Returns [None] if:
    - window.__SOLID_ML_DATA__ doesn't exist
    - The key is not present
    - The data is not a valid JSON object
*)

val decode : key:string -> decode:(json -> 'a option) -> default:'a -> 'a
(** [decode ~key ~decode ~default] decodes state with a fallback.

    The [decode] function converts JSON to your type.
    Returns [default] if the key doesn't exist or decoding fails.

    {[
      (* Decode an integer *)
      let count = State.decode
        ~key:"counter"
        ~decode:(fun j -> Js.Json.decodeNumber j |> Option.map int_of_float)
        ~default:0

      (* Decode a custom type *)
      type user = { name: string; id: int }
      let decode_user (json : json) : user option =
        match Js.Json.decodeObject json with
        | None -> None
        | Some obj ->
          let name = Js.Dict.get obj "name" in
          let id = Js.Dict.get obj "id" in
          match (name, id) with
          | (Some n, Some i) ->
            (match (Js.Json.decodeString n, Js.Json.decodeNumber i) with
            | (Some name_str, Some id_num) ->
              Some { name = name_str; id = int_of_float id_num }
            | _ -> None)
          | _ -> None

      let user = State.decode
        ~key:"user"
        ~decode:decode_user
        ~default:{ name = "Guest"; id = 0 }
        ()
    ]}
*)

(** {1 Writing State (client-side)} *)

val set : key:string -> json -> unit
(** [set ~key value] stores state in window.__SOLID_ML_DATA__.

    Creates the global object if it doesn't exist.
    Mainly useful for client-side state management.
*)

val set_encoded : key:string -> encode:('a -> json) -> 'a -> unit
(** [set_encoded ~key ~encode value] encodes and stores a value.

    {[
      State.set_encoded
        ~key:"counter"
        ~encode:State.encode_int
        42
    ]}
*)

(** {1 Encoders} *)

val encode_string : string -> json
(** Encode a string to JSON. *)

val encode_int : int -> json
(** Encode an int to JSON. *)

val encode_float : float -> json
(** Encode a float to JSON. *)

val encode_bool : bool -> json
(** Encode a bool to JSON. *)

val encode_null : json
(** JSON null value. *)

val encode_list : json list -> json
(** Encode a list of JSON values to a JSON array. *)

val encode_object : (string * json) list -> json
(** Encode key-value pairs to a JSON object.

    {[
      State.encode_object [
        ("name", State.encode_string "Alice");
        ("age", State.encode_int 30);
        ("admin", State.encode_bool true);
      ]
    ]}
*)
