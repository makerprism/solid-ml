(** Shared types for State Hydration Demo.

    This file contains type definitions used by both server and client.
    The actual component implementations are in server/components.ml and client/components.ml
    to avoid package type issues with functors.
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
