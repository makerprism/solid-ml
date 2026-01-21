(** Client Implementation of Platform Interface *)

module Client_Platform : Shared_components.Platform_intf.S
  with type Html.node = Solid_ml_browser.Html.node
   and type Html.event = Solid_ml_browser.Html.event
   and type 'a Signal.t = 'a Solid_ml_browser.Reactive.Signal.t = struct
  module Signal = struct
    type 'a t = 'a Solid_ml_browser.Reactive.Signal.t
    let create v = Solid_ml_browser.Reactive.Signal.create ?equals:None v
    let get = Solid_ml_browser.Reactive.Signal.get
    let set = Solid_ml_browser.Reactive.Signal.set
    let update = Solid_ml_browser.Reactive.Signal.update
    let peek = Solid_ml_browser.Reactive.Signal.peek
  end
  module Memo = struct
    include Solid_ml_browser.Reactive.Memo
    (* Adapt signature *)
    let create f = create ?equals:None f
    
    let as_signal m = 
      (* Direct read via functional signal wrapper if supported, 
         or just create a signal that updates. *)
      let initial = get m in
      let s, set_s = Signal.create initial in
      Solid_ml_browser.Reactive.Effect.create (fun () -> set_s (get m));
      s
  end
  module Effect = Solid_ml_browser.Reactive.Effect
  
  module Html = struct
    (* We need to wrap Solid_ml_browser.Html to match the interface signature *)
    include Solid_ml_browser.Html

    type 'a signal = 'a Signal.t

    let reactive_text (s : int signal) =
      Solid_ml_browser.Html.reactive_text (s : int Solid_ml_browser.Html.signal)

    let reactive_text_string (s : string signal) =
      Solid_ml_browser.Html.reactive_text_string (s : string Solid_ml_browser.Html.signal)
    
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

    let input ?id ?type_ ?value ?checked ?oninput ?onchange () =
      input ?id ?type_ ?value ?checked ?oninput ?onchange ()
      
    let ul ?id ?class_ ?children () =
      ul ?id ?class_ ~children:(Option.value children ~default:[]) ()
      
    let li ?id ?class_ ?children () =
      li ?id ?class_ ~children:(Option.value children ~default:[]) ()
      
    let a ?href ?class_ ?onclick ~children () =
      let href = href in (* Dummy use to suppress unused variable warning if signature changes *)
      let class_ = class_ in
      let onclick = onclick in
      a ?href ?class_ ?onclick ~children ()
      
    let prevent_default evt = Solid_ml_browser.Dom.prevent_default evt
  end

  module For = struct
    let list (items_signal : 'a list Signal.t) render =
      Solid_ml_browser.For.create' ~each:items_signal ~children:render ()
  end

  module Router = struct
    open Solid_ml_router

    (* Instantiate Router Components with Browser HTML 
       But we need to adapt the HTML module because Solid_ml_browser.Html events 
       are 'event' (Dom.event), while Router Components expect 'unit -> unit' 
       for SSR compatibility.
       
       Wait, `Solid_ml_router.Components.Make` expects:
       `val a : ... ?onclick:(unit -> unit) ...`
       
       But `Solid_ml_browser.Html.a` has:
       `val a : ... ?onclick:(event -> unit) ...`
       
       So we can't pass `Solid_ml_browser.Html` directly to `Components.Make`.
       We need an adapter module.
    *)
    
    module HtmlAdapter = struct
      include Solid_ml_browser.Html
      
      let a ?id ?class_ ?href ?target ?rel ?download ?hreflang ?tabindex ?onclick ?data ?attrs ~children () =
        let onclick_handler = 
          match onclick with
          | Some f -> Some (fun (_:event) -> f ())
          | None -> None
        in
        Solid_ml_browser.Html.a ?id ?class_ ?href ?target ?rel ?download ?hreflang ?tabindex ?onclick:onclick_handler ?data ?attrs ~children ()
        
      let fragment = Solid_ml_browser.Html.fragment
    end

    module C = Solid_ml_router.Components.Make(HtmlAdapter)

    let use_path () = Router.use_path ()
    
    let use_params () = 
      let params = Router.use_params () in
      Route.Params.to_list params

    let use_query_param _key = None


    let navigate path = Router.navigate path

    let link ~href ?class_ ~children () =
      (* Use the browser-specific Link component *)
      C.link ~href ?class_ ~children ()
  end
end

module Shared = Shared_components.Components.Make(Client_Platform)
