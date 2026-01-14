open Ppxlib

let () =
  Driver.register_transformation
    ~impl:(fun s -> s)
    "solid-ml-template-ppx"
