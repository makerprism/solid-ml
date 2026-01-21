(** Server Implementation of Platform Interface *)

module Server_Platform : (Shared_components.Platform_intf.S 
  with type Html.node = Solid_ml_ssr.Html.node 
  and type Html.event = unit) = struct
  module Signal = struct
    type 'a t = 'a Solid_ml.Signal.t

    let create v = Solid_ml.Signal.Unsafe.create v
    let get = Solid_ml.Signal.get
    let set = Solid_ml.Signal.set
    let update = Solid_ml.Signal.update
    let peek = Solid_ml.Signal.peek
  end
  module Memo = struct
    type 'a t = 'a Solid_ml.Memo.t

    let create f = Solid_ml.Memo.Unsafe.create f
    let get = Solid_ml.Memo.Unsafe.get

    (* Convert Memo to read-only Signal via a computed *)
    let as_signal m =
      let initial = get m in
      let s, set_s = Solid_ml.Signal.Unsafe.create initial in
      Solid_ml.Effect.Unsafe.create (fun () ->
        set_s (get m)
      );
      s
  end
  module Effect = Solid_ml.Effect.Unsafe
  
  module Html = struct
    include Solid_ml_ssr.Html
    
    (* Re-export/adapt types to match interface *)
    type event = unit
    let prevent_default () = ()
    
    (* SSR doesn't execute handlers, so we just ignore them *)
    let div ?id ?class_ ?onclick ~children () = 
      let _ = onclick in 
      div ?id ?class_ ~children ()
      
    let button ?id ?class_ ?onclick ~children () = 
      let _ = onclick in
      button ?id ?class_ ~children ()
      
    let a ?href ?class_ ?onclick ~children () =
      let _ = onclick in
      a ?href ?class_ ~children ()
      
    let span ?id ?class_ ?(children=[]) () =
      span ?id ?class_ ~children ()

    let p ?(children=[]) () =
      p ~children ()

    let h1 ?(children=[]) () =
      h1 ~children ()

    let h2 ?(children=[]) () =
      h2 ~children ()

    let ul ?id ?class_ ?(children=[]) () =
      ul ?id ?class_ ~children ()

    let li ?id ?class_ ?(children=[]) () =
      li ?id ?class_ ~children ()

    let input ?id ?type_ ?value ?checked ?oninput ?onchange () =
      let _ = oninput in
      let _ = onchange in
      input ?id ?type_ ?value ?checked ()
  end

  module For = struct
    let list items_signal render =
      (* On server, just map the current signal value *)
      let items = Signal.get items_signal in
      Html.fragment (List.map render items)
  end

  module Router = struct
    (* For SSR, we need a way to provide the initial path.
       In a real implementation, we'd probably use a context or global variable
       set during the request handling. For this simple platform adapter,
       we'll assume there's a mechanism to get the current request context.
       
       However, the Router module in solid-ml-router is designed to be cross-platform mostly.
       But on the server, `navigate` is a no-op (or maybe a redirect?), 
       and `use_path` should come from the request URL.
       
       The solid-ml-router library actually handles this via `Router.context`.
       So we can just wrap `Solid_ml_router.Router`.
       
       Wait, `Solid_ml_router` depends on `Solid_ml`.
       Does `Solid_ml_router` work on the server?
       Yes, it's isomorphic.
    *)
    
    let use_path () = 
      try Solid_ml_router.Router.use_path () 
      with Solid_ml_router.Router.No_router_context -> "/"

    let use_params () =
      try 
        let params = Solid_ml_router.Router.use_params () in
        Solid_ml_router.Route.Params.to_list params
      with Solid_ml_router.Router.No_router_context -> []

    let use_query_param key =
      try
        let loc = Solid_ml_router.Router.use_location () in
        let query = (Solid_ml.Signal.get loc).Solid_ml_router.Router.query in
        Solid_ml_router.Router.get_query_param key query
      with Solid_ml_router.Router.No_router_context -> None

    let navigate path =
      (* On server, navigate is usually a no-op during rendering *)
      try Solid_ml_router.Router.navigate path
      with Solid_ml_router.Router.No_router_context -> ()

    let link ~href ?class_ ~children () =
      (* We can use the simple anchor tag for SSR, or the Link component if we want 
         to support client-side navigation after hydration. 
         Solid_ml_router.Components.Link renders an <a> tag that intercepts clicks. 
         For SSR, it just renders an <a> tag. *)
      Solid_ml_router.Components.Link.make ~href ?class_ ~children ()
  end
end

module Shared = Shared_components.Components.Make(Server_Platform)
