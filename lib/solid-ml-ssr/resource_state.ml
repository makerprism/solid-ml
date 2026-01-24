let set ~key ~encode (resource : ('a, string) Solid_ml.Resource.resource) : unit =
  match Solid_ml.Resource.peek resource with
  | Solid_ml.Resource.Pending ->
    State.set_encoded
      ~key
      ~encode:(fun () -> State.encode_resource_loading ())
      ()
  | Solid_ml.Resource.Ready value ->
    State.set_encoded
      ~key
      ~encode:(fun v -> State.encode_resource_ready (encode v))
      value
  | Solid_ml.Resource.Error message ->
    State.set_encoded
      ~key
      ~encode:(fun msg -> State.encode_resource_error msg)
      message
