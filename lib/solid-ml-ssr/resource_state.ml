let set ~key ~encode (resource : ('a, string) Solid_ml_server.Resource.resource) : unit =
  match Solid_ml_server.Resource.peek resource with
  | Solid_ml_server.Resource.Ready value ->
    State.set_encoded
      ~key
      ~encode:(fun v -> State.encode_resource_ready (encode v))
      value
  | Solid_ml_server.Resource.Error message ->
    State.set_encoded
      ~key
      ~encode:(fun msg -> State.encode_resource_error msg)
      message
  | _ ->
    State.set_encoded
      ~key
      ~encode:(fun () -> State.encode_resource_loading ())
      ()
