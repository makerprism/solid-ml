(** solid-ml-router: SSR-aware routing for solid-ml.
    
    This library provides routing with support for:
    - Pattern matching with parameters and wildcards
    - Server-side route matching for SSR
    - (Future) Client-side navigation
    
    {1 Basic Usage}
    
    {[
      open Solid_ml_router
      
      (* Define routes *)
      let home_route = Route.create ~path:"/" ~data:`Home
      let users_route = Route.create ~path:"/users" ~data:`Users
      let user_route = Route.create ~path:"/users/:id" ~data:`User
      
      let routes = [home_route; users_route; user_route]
      
      (* Match a path *)
      match Route.match_routes routes "/users/123" with
      | Some (route, result) ->
        let user_id = Route.Params.get "id" result.params in
        (* user_id = Some "123" *)
      | None ->
        (* No matching route *)
    ]}
    
    {1 Modules}
*)

(** Route definition and pattern matching *)
module Route = Route
