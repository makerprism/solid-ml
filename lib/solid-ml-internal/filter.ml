(** Route parameter match filters (shared between server and browser).
    
    Match filters validate route parameters at match time.
    A route only matches if all its parameter filters pass.
    
    Example:
    {[
      let user_route = Route.create
        ~path:"/users/:id"
        ~filters:[("id", Filter.positive_int)]
        ~data:user_component
        ()
    ]}
*)

(** A filter function that validates a parameter value.
    Returns [true] if the value is valid, [false] otherwise. *)
type match_filter = string -> bool

(** A map from parameter names to their filters *)
type filters = (string * match_filter) list

(** {1 Built-in Filters} *)

(** Match any non-empty string (always passes for captured params) *)
let any : match_filter = fun _ -> true

(** Match strings that parse as integers *)
let int : match_filter = fun s ->
  match int_of_string_opt s with
  | Some _ -> true
  | None -> false

(** Match strings that parse as positive integers (> 0) *)
let positive_int : match_filter = fun s ->
  match int_of_string_opt s with
  | Some n -> n > 0
  | None -> false

(** Match strings that parse as non-negative integers (>= 0) *)
let non_negative_int : match_filter = fun s ->
  match int_of_string_opt s with
  | Some n -> n >= 0
  | None -> false

(** Match strings that parse as floats *)
let float : match_filter = fun s ->
  match float_of_string_opt s with
  | Some _ -> true
  | None -> false

(** Match strings that look like UUIDs (basic check).
    Matches format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    Case-insensitive for hex digits. *)
let uuid : match_filter = fun s ->
  let len = String.length s in
  if len <> 36 then false
  else
    let is_hex c =
      (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
    in
    let is_dash i = (i = 8 || i = 13 || i = 18 || i = 23) in
    let rec check i =
      if i >= len then true
      else if is_dash i then
        s.[i] = '-' && check (i + 1)
      else
        is_hex s.[i] && check (i + 1)
    in
    check 0

(** Match strings that contain only alphanumeric characters *)
let alphanumeric : match_filter = fun s ->
  let len = String.length s in
  if len = 0 then false
  else
    let rec check i =
      if i >= len then true
      else
        let c = s.[i] in
        ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'))
        && check (i + 1)
    in
    check 0

(** Match strings that contain only lowercase letters, digits, and hyphens (slug format) *)
let slug : match_filter = fun s ->
  let len = String.length s in
  if len = 0 then false
  else
    let rec check i =
      if i >= len then true
      else
        let c = s.[i] in
        ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c = '-')
        && check (i + 1)
    in
    check 0

(** Match one of the given exact values *)
let one_of (values : string list) : match_filter = fun s ->
  List.mem s values

(** Match strings with length in given range (inclusive) *)
let length ~min ~max : match_filter = fun s ->
  let len = String.length s in
  len >= min && len <= max

(** Match strings with exact length *)
let exact_length (n : int) : match_filter = fun s ->
  String.length s = n

(** Match strings with minimum length *)
let min_length min : match_filter = fun s ->
  String.length s >= min

(** Match strings with maximum length *)
let max_length max : match_filter = fun s ->
  String.length s <= max

(** Combine multiple filters with AND logic *)
let all (filters : match_filter list) : match_filter = fun s ->
  List.for_all (fun f -> f s) filters

(** Combine multiple filters with OR logic *)
let any_of (filters : match_filter list) : match_filter = fun s ->
  List.exists (fun f -> f s) filters

(** Negate a filter *)
let not_ (f : match_filter) : match_filter = fun s ->
  not (f s)

(** Custom predicate filter *)
let predicate (f : string -> bool) : match_filter = f

(** {1 Validation} *)

(** Check if all params pass their corresponding filters.
    Returns true if all filters pass (or no filters defined). *)
let validate (filters : filters) (params : (string * string) list) : bool =
  List.for_all (fun (name, filter) ->
    match List.assoc_opt name params with
    | None -> true  (* Param not captured - filter doesn't apply *)
    | Some value -> filter value
  ) filters
