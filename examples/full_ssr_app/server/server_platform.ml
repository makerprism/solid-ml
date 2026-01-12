(** Server Implementation of Platform Interface *)

module Server_Platform : Shared_components.Platform_intf.S = struct
  module Signal = Solid_ml.Signal
  module Memo = struct 
    include Solid_ml.Memo
    (* Convert Memo to read-only Signal via a computed *)
    let as_signal m = Solid_ml.Signal.create_computed (fun () -> get m)
  end
  module Effect = Solid_ml.Effect
  
  module Html = struct
    include Solid_ml_ssr.Html
    
    (* Re-export/adapt types to match interface *)
    type event = unit
    let prevent_default () = ()
    
    (* SSR doesn't execute handlers, so we just ignore them *)
    let div ?id ?class_ ?onclick = 
      let _ = onclick in 
      div ?id ?class_
      
    let button ?id ?class_ ?onclick = 
      let _ = onclick in
      button ?id ?class_
      
    let a ?href ?class_ ?onclick =
      let _ = onclick in
      a ?href ?class_
      
    let input ?type_ ?checked ?oninput ?onchange () =
      let _ = oninput in
      let _ = onchange in
      input ?type_ ?checked ()
  end
end

module Shared = Shared_components.Components.Make(Server_Platform)
