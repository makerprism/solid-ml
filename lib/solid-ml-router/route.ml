(** Route definition and pattern matching.
    
    Routes are defined with path patterns that can include:
    - Static segments: "/users/profile"
    - Dynamic parameters: "/users/:id"
    - Wildcards: "/files/*"
    
    Example:
    {[
      let user_route = Route.create
        ~path:"/users/:id"
        ~component:(fun ~params () ->
          let id = Params.get "id" params in
          User_page.make ~id ()
        )
    ]}
*)

(** {1 Types} *)

(** Parameters extracted from route matching *)
module Params = struct
  type t = (string * string) list
  
  let empty : t = []
  
  let get key (params : t) =
    List.assoc_opt key params
  
  let get_exn key (params : t) =
    List.assoc key params
  
  let add key value (params : t) : t =
    (key, value) :: params
  
  let of_list pairs : t = pairs
  
  let to_list (params : t) = params
  
  let is_empty (params : t) = params = []
  
  let iter f (params : t) = List.iter (fun (k, v) -> f k v) params
end

(** A segment in a route pattern *)
type segment =
  | Static of string      (** Exact match required *)
  | Param of string       (** Named parameter (:name) *)
  | Wildcard              (** Match rest of path [*] *)

(** A compiled route pattern *)
type pattern = segment list

(** Result of matching a path against a route *)
type match_result = {
  params : Params.t;
  path : string;
}

(** A route with its pattern and associated data *)
type 'a t = {
  pattern : pattern;
  path_template : string;
  data : 'a;
}

(** {1 Pattern Parsing} *)

(** Parse a path template into segments.
    
    Examples:
    - "/" -> [Static ""]
    - "/users" -> [Static "users"]
    - "/users/:id" -> [Static "users"; Param "id"]
    - "/files/*" -> [Static "files"; Wildcard]
*)
let parse_pattern path =
  let segments = String.split_on_char '/' path in
  (* Remove empty first segment from leading "/" *)
  let segments = match segments with
    | "" :: rest -> rest
    | segs -> segs
  in
  List.map (fun seg ->
    if String.length seg > 0 && seg.[0] = ':' then
      Param (String.sub seg 1 (String.length seg - 1))
    else if seg = "*" then
      Wildcard
    else
      Static seg
  ) segments

(** {1 Pattern Matching} *)

(** Match a path against a pattern.
    Returns Some params if match succeeds, None otherwise. *)
let match_pattern pattern path =
  let path_segments = String.split_on_char '/' path in
  let path_segments = match path_segments with
    | "" :: rest -> rest
    | segs -> segs
  in
  
  let rec match_segments pattern_segs path_segs params =
    match pattern_segs, path_segs with
    (* Both empty - match! *)
    | [], [] -> Some params
    (* Both empty except trailing empty from "/" *)
    | [], [""] -> Some params
    (* Pattern exhausted but path has more - no match *)
    | [], _ -> None
    (* Wildcard matches everything remaining *)
    | [Wildcard], rest ->
      let wildcard_value = String.concat "/" rest in
      Some (Params.add "*" wildcard_value params)
    (* Wildcard not at end - invalid pattern *)
    | Wildcard :: _, _ -> None
    (* Path exhausted but pattern has more - no match *)
    | _, [] -> None
    (* Static segment must match exactly *)
    | Static s :: pattern_rest, seg :: path_rest when s = seg ->
      match_segments pattern_rest path_rest params
    | Static _ :: _, _ -> None
    (* Param captures the segment value - must be non-empty *)
    | Param name :: pattern_rest, seg :: path_rest when seg <> "" ->
      match_segments pattern_rest path_rest (Params.add name seg params)
    | Param _ :: _, _ -> None
  in
  
  match_segments pattern path_segments Params.empty

(** {1 Route Creation} *)

(** Create a route from a path template and associated data.
    
    The path template supports:
    - Static segments: "/users/profile"
    - Named parameters: "/users/:id" (extracted as params)
    - Wildcards: "/files/*" (captures rest of path)
    
    @param path The path template
    @param data Data associated with this route (e.g., component, loader) *)
let create ~path ~data =
  let pattern = parse_pattern path in
  { pattern; path_template = path; data }

(** {1 Route Matching} *)

(** Match a path against a single route.
    Returns Some match_result if the path matches, None otherwise. *)
let match_route route path =
  match match_pattern route.pattern path with
  | Some params -> Some { params; path }
  | None -> None

(** Match a path against a list of routes.
    Returns the first matching route and its match result. *)
let match_routes routes path =
  let rec try_routes = function
    | [] -> None
    | route :: rest ->
      match match_route route path with
      | Some result -> Some (route, result)
      | None -> try_routes rest
  in
  try_routes routes

(** {1 Path Generation} *)

(** Generate a path from a route template and parameters.
    
    Example:
    {[
      let path = Route.generate_path "/users/:id" [("id", "123")]
      (* path = "/users/123" *)
    ]}
*)
let generate_path template params =
  let segments = String.split_on_char '/' template in
  let filled = List.map (fun seg ->
    if String.length seg > 0 && seg.[0] = ':' then
      let name = String.sub seg 1 (String.length seg - 1) in
      match List.assoc_opt name params with
      | Some value -> value
      | None -> seg  (* Keep original if param not found *)
    else
      seg
  ) segments in
  String.concat "/" filled

(** Get the original path template of a route *)
let path_template route = route.path_template

(** Get the data associated with a route *)
let data route = route.data
