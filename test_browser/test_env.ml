(* Compile-only check: Solid_ml_browser.Env satisfies the shared template env.

   This file is included in the melange.emit stanza for test_browser, so it will
   be compiled as part of `dune build @test_browser/melange`.

   No runtime assertions are needed; the module constraint is the test.
*)

let _ =
  (module Solid_ml_browser.Env : Solid_ml_template_runtime.Env_intf.TEMPLATE_ENV)
