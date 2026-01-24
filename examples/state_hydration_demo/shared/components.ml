(** Shared types for State Hydration Demo.

    This file contains type definitions used by both server and client.
    Component implementations are in server/main.ml and client/main.ml
    (inlined to avoid package type issues with functors).
*)

type user = {
  name: string;
  id: int;
  email: string;
}

type cart_item = {
  id: int;
  name: string;
  price: float;
  quantity: int;
}
