(** SSR router components using solid-ml-ssr Html. *)

module Base = Solid_ml_router.Components.Make (Html)

module Link = struct
  include Base
  let make = link
end

include Link
