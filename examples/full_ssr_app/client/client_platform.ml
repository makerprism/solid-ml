(** Client Implementation of Platform Interface *)

module Client_Platform : Shared_components.Platform_intf.S = struct
  module Signal = struct 
    include Solid_ml_browser.Reactive.Signal
    (* Adapt signature to match interface (remove optional args) *)
    let create v = create ?equals:None v
  end
  module Memo = struct
    include Solid_ml_browser.Reactive.Memo
    (* Adapt signature *)
    let create f = create ?equals:None f
    
    let as_signal m = 
      (* Direct read via functional signal wrapper if supported, 
         or just create a signal that updates. *)
      let initial = get m in
      let s, set_s = Solid_ml_browser.Reactive.Signal.create initial in
      Solid_ml_browser.Reactive.Effect.create (fun () ->
        set_s (get m)
      );
      s
  end
  module Effect = Solid_ml_browser.Reactive.Effect
  
  module Html = struct
    (* We need to wrap Solid_ml_browser.Html to match the interface signature *)
    include Solid_ml_browser.Html
    
    (* Re-export types to satisfy the signature *)
    (* In browser html.mli: type 'a signal = 'a Reactive_core.signal *)
    (* In client_platform Signal: type 'a t = 'a Reactive.Signal.t *)
    (* These are the same underlying type, but we need to prove it *)
    
    let reactive_text s = reactive_text (Obj.magic s)
    let reactive_text_string s = reactive_text_string (Obj.magic s)
    
    (* Adapt function signatures by ignoring extra optional arguments *)
    let div ?id ?class_ ?onclick ~children () = 
      div ?id ?class_ ?onclick ~children ()

    let span ?id ?class_ ?children () =
      span ?id ?class_ ~children:(Option.value children ~default:[]) ()

    let p ?children () = 
      p ~children:(Option.value children ~default:[]) ()

    let h1 ?children () = 
      h1 ~children:(Option.value children ~default:[]) ()

    let h2 ?children () = 
      h2 ~children:(Option.value children ~default:[]) ()

    let button ?id ?class_ ?onclick ~children () = 
      button ?id ?class_ ?onclick ~children ()

    let input ?type_ ?checked ?oninput ?onchange () =
      input ?type_ ?checked ?oninput ?onchange ()

    let ul ?id ?class_ ?children () =
      ul ?id ?class_ ~children:(Option.value children ~default:[]) ()

    let li ?id ?class_ ?children () =
      li ?id ?class_ ~children:(Option.value children ~default:[]) ()

    let a ?href ?class_ ?onclick ~children () =
      a ?href ?class_ ?onclick ~children ()

    type event = Solid_ml_browser.Dom.event
    let prevent_default = Solid_ml_browser.Dom.prevent_default
  end
end

module Shared = Shared_components.Components.Make(Client_Platform)
