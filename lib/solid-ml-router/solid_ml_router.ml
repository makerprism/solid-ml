(** solid-ml-router: SSR-aware routing for solid-ml.
    
    This library provides routing with support for:
    - Pattern matching with parameters and wildcards
    - Server-side route matching for SSR
    - Reactive router state
    - URL parsing and building
    
    {1 Basic Usage}
    
    {[
      open Solid_ml_router
      
      (* Define routes *)
      let home_route = Route.create ~path:"/" ~data:`Home ()
      let users_route = Route.create ~path:"/users" ~data:`Users ()
      let user_route = Route.create ~path:"/users/:id" ~data:`User ()
      
      let routes = [home_route; users_route; user_route]
      
      (* Match a path *)
      match Route.match_routes routes "/users/123" with
      | Some (route, result) ->
        let user_id = Route.Params.get "id" result.params in
        (* user_id = Some "123" *)
      | None ->
        (* No matching route *)
    ]}
    
    {1 Using the Router}
    
    {[
      (* In a component *)
      let my_component () =
        let path = Router.use_path () in
        let user_id = Router.use_param "id" in
        ...
        
      (* Navigate programmatically *)
      Router.navigate "/users/123"
    ]}
    
    {1 Modules}
*)

(** Route definition and pattern matching *)
module Route = Route

(** Router state and navigation *)
module Router = Router

(** Router components (Link, Outlet, provide) *)
module Components = Components

(** Async resource with loading/error/ready states *)
module Resource = Resource
