(** Route definition and pattern matching.
    
    Routes are defined with path patterns that can include:
    - Static segments: "/users/profile"
    - Dynamic parameters: "/users/:id"
    - Wildcards: "/files/*"
    
    Match filters can validate parameters at match time:
    - Only routes whose params pass all filters will match
    - Built-in filters: [int], [positive_int], [uuid], [regex]
    
    Example:
    {[
      let user_route = Route.create
        ~path:"/users/:id"
        ~filters:[("id", Filter.positive_int)]
        ~component:(fun ~params () ->
          let id = Params.get "id" params in
          User_page.make ~id ()
        )
    ]}
*)

(** {1 Types} *)

(** {2 Match Filters} *)

(** Re-export shared Filter module *)
module Filter = Solid_ml_internal.Filter

(** A filter function that validates a parameter value.
    Returns [true] if the value is valid, [false] otherwise. *)
type match_filter = Filter.match_filter

(** A map from parameter names to their filters *)
type filters = Filter.filters

(** {2 Parameters} *)

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
  filters : filters;
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

(** {2 URL Encoding/Decoding} *)

(** Decode a percent-encoded path segment.
    Converts %XX sequences to their character equivalents.
    Does not treat + as space. *)
let path_decode s =
  let len = String.length s in
  let buf = Buffer.create len in
  let i = ref 0 in
  while !i < len do
    let c = s.[!i] in
    if c = '%' && !i + 2 < len then begin
      let hex = String.sub s (!i + 1) 2 in
      match int_of_string_opt ("0x" ^ hex) with
      | Some code ->
        Buffer.add_char buf (Char.chr code);
        i := !i + 3
      | None ->
        Buffer.add_char buf c;
        incr i
    end else begin
      Buffer.add_char buf c;
      incr i
    end
  done;
  Buffer.contents buf

(** Encode a string for use in path segments.
    Converts special characters to %XX sequences. *)
let path_encode s =
  let len = String.length s in
  let buf = Buffer.create (len * 3) in
  for i = 0 to len - 1 do
    let c = s.[i] in
    match c with
    | 'a'..'z' | 'A'..'Z' | '0'..'9' | '-' | '_' | '.' | '~' ->
      Buffer.add_char buf c
    | _ ->
      Buffer.add_string buf (Printf.sprintf "%%%02X" (Char.code c))
  done;
  Buffer.contents buf

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
      let wildcard_value = String.concat "/" rest |> path_decode in
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
      let decoded = path_decode seg in
      match_segments pattern_rest path_rest (Params.add name decoded params)
    | Param _ :: _, _ -> None
  in
  
  match_segments pattern path_segments Params.empty

(** Check if all params pass their corresponding filters.
    Returns true if all filters pass (or no filters defined). *)
let validate_filters = Filter.validate

(** {1 Route Creation} *)

(** Create a route from a path template and associated data.
    
    The path template supports:
    - Static segments: "/users/profile"
    - Named parameters: "/users/:id" (extracted as params)
    - Wildcards: "/files/*" (captures rest of path)
    
    Optional filters validate captured parameters at match time.
    A route only matches if all its filters pass.
    
    @param path The path template
    @param data Data associated with this route (e.g., component, loader)
    @param filters Optional list of (param_name, filter) pairs
    
    Example:
    {[
      Route.create 
        ~path:"/users/:id/posts/:post_id"
        ~data:user_posts_component
        ~filters:[("id", Filter.positive_int); ("post_id", Filter.positive_int)]
        ()
    ]}
*)
let create ~path ~data ?(filters=[]) () =
  let pattern = parse_pattern path in
  { pattern; path_template = path; filters; data }

(** {1 Route Matching} *)

(** Match a path against a single route.
    Returns Some match_result if the path matches and all filters pass, 
    None otherwise. *)
let match_route route path =
  match match_pattern route.pattern path with
  | Some params ->
    (* Validate params against filters *)
    if validate_filters route.filters params then
      Some { params; path }
    else
      None
  | None -> None

(** Match a path against a list of routes.
    Routes are ranked by specificity; ties preserve list order. *)
let match_routes routes path =
  let score_pattern pattern =
    let static_count = ref 0 in
    let param_count = ref 0 in
    let wildcard_count = ref 0 in
    let segment_count = ref 0 in
    List.iter (function
      | Static _ -> incr static_count; incr segment_count
      | Param _ -> incr param_count; incr segment_count
      | Wildcard -> incr wildcard_count; incr segment_count
    ) pattern;
    (!static_count, !param_count, - !wildcard_count, !segment_count)
  in
  let compare_score (a1, a2, a3, a4) (b1, b2, b3, b4) =
    match compare a1 b1 with
    | 0 -> (match compare a2 b2 with
      | 0 -> (match compare a3 b3 with
        | 0 -> compare a4 b4
        | c -> c)
      | c -> c)
    | c -> c
  in
  let best = ref None in
  let i = ref 0 in
  List.iter (fun route ->
    let index = !i in
    incr i;
    match match_route route path with
    | None -> ()
    | Some result ->
      let score = score_pattern route.pattern in
      match !best with
      | None -> best := Some (route, result, score, index)
      | Some (_best_route, _best_result, best_score, best_index) ->
        let cmp = compare_score score best_score in
        if cmp > 0 || (cmp = 0 && index < best_index) then
          best := Some (route, result, score, index)
  ) routes;
  match !best with
  | None -> None
  | Some (route, result, _, _) -> Some (route, result)

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
      | Some value -> path_encode value
      | None -> seg  (* Keep original if param not found *)
    else
      seg
  ) segments in
  String.concat "/" filled

(** Get the original path template of a route *)
let path_template route = route.path_template

(** Get the data associated with a route *)
let data route = route.data

(** Get the filters associated with a route *)
let get_filters route = route.filters
