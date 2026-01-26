# State Module Hydration Demo

This example demonstrates how to use the **State module** to transfer application state from the server to the client for hydration.

## What is State Transfer?

In server-side rendering (SSR), you often need to pass data from the server (where it comes from a database or API) to the client (for hydration). The `State` module provides a clean way to do this:

1. **Server**: Store state using `State.set_encoded`
2. **Server**: Generate script tag with `Render.get_hydration_script()`
3. **Client**: Retrieve state using `State.decode`

## Server-Side Usage

```ocaml
(* 1. Store state before rendering *)
let counter_key = State.key ~namespace:"demo" "counter" in
State.set_encoded ~key:counter_key ~encode:State.encode_int 100;

(* 2. Render your component *)
let html = Render.to_document (fun () ->
  my_component ~initial:100 ()
)

(* 3. Get the hydration script *)
let script = Render.get_hydration_script ()

(* 4. Include both in your response *)
let full_response = html ^ script
```

### Encoding Different Types

```ocaml
(* Primitives *)
State.set_encoded ~key:"count" ~encode:State.encode_int 42
State.set_encoded ~key:"name" ~encode:State.encode_string "Alice"
State.set_encoded ~key:"active" ~encode:State.encode_bool true

(* Objects *)
let encode_user user =
  State.encode_object [
    ("name", State.encode_string user.name);
    ("id", State.encode_int user.id);
  ]
State.set_encoded ~key:"user" ~encode:encode_user my_user

(* Lists *)
State.set_encoded
  ~key:"items"
  ~encode:State.encode_list
  [State.encode_int 1; State.encode_int 2; State.encode_int 3]

(* Lists of complex objects *)
let encode_item item =
  State.encode_object [
    ("id", State.encode_int item.id);
    ("name", State.encode_string item.name);
  ]
State.set_encoded
  ~key:"cart"
  ~encode:State.encode_list
  (List.map encode_item cart_items)
```

## Client-Side Usage

```ocaml
(* 1. Retrieve state with a fallback *)
let counter_key = State.key ~namespace:"demo" "counter" in
let initial =
  State.decode
    ~key:counter_key
    ~decode:(fun json ->
      Js.Json.decodeNumber json
      |> Option.map int_of_float
    )
    ~default:0

(* 2. Use the state during hydration *)
let () =
  match Dom.get_element_by_id (Dom.document ()) "app" with
  | Some app_el ->
    let _disposer = Render.hydrate app_el (fun () ->
      Counter.create ~initial
    ) in
    ()
  | None -> ()
```

### Decoding Different Types

```ocaml
(* Primitives *)
let count =
  State.decode
    ~key:"count"
    ~decode:(fun j -> Js.Json.decodeNumber j |> Option.map int_of_float)
    ~default:0
    ()

(* Objects *)
let decode_user json =
  match Js.Json.decodeObject json with
  | None -> None
  | Some obj ->
    match (Js.Dict.get obj "name", Js.Dict.get obj "id") with
    | (Some n, Some i) ->
      begin match Js.Json.decodeString n, decode_int i with
      | (Some name_str, Some id_int) ->
        Some { name = name_str; id = id_int }
      | _ -> None
      end
    | _ -> None

let user = State.decode ~key:"user" ~decode:decode_user ~default:default_user

(* Arrays *)
let decode_item_array json =
  match Js.Json.decodeArray json with
  | None -> None
  | Some arr ->
    let items = Array.fold_right (fun j acc ->
      match decode_item j with
      | Some i -> i :: acc
      | None -> acc
    ) arr [] in
    Some items

let items = State.decode ~key:"items" ~decode:decode_item_array ~default:[]
```

## Running This Example

### Server (Native)

```bash
dune build examples/state_hydration_demo/server.exe
dune exec examples/state_hydration_demo/server.exe
```

This will output HTML pages with the state serialization script.

### Client (Browser)

Build the client code:
```bash
dune build @examples/state_hydration_demo/client
```

The output will be in `_build/default/examples/state_hydration_demo/output/client.js`

## What Gets Generated

When you run the server example, you'll see:

```html
<!DOCTYPE html>
<html lang="en">
<head>...</head>
<body>
  <div class="container">
    <!-- Your rendered content -->
  </div>
  <script>window.__SOLID_ML_DATA__ = {"demo:counter":100,"demo:user":{...},...};</script>
</body>
</html>
```

The `window.__SOLID_ML_DATA__` object contains all the state you set on the server, which the client can then retrieve using `State.decode`.

## Key Points

1. **Namespaced Keys**: Use `State.key ~namespace:"app" "name"` to avoid conflicts
2. **Type Safety**: Always provide a `default` value in `decode`
3. **Proper Encoding**: Match your encode/decode functions for each type
4. **Hydration API**: Use `Render.hydrate` (or `Render.hydrate_with`) to adopt server HTML
5. **Include Script**: Don't forget `Render.get_hydration_script()` to embed the data
6. **Cleanup**: State is automatically reset between renders

## Common Patterns

### Database Query Results

```ocaml
(* Server *)
let users = Database.fetch_users () in
let encode_user u = State.encode_object [...]
let encoded = List.map encode_user users in
State.set_encoded ~key:"users" ~encode:State.encode_list encoded

(* Client *)
let users =
  State.decode
    ~key:"users"
    ~decode:decode_user_array
    ~default:[]
    ()
```

### API Response Data

```ocaml
(* Server *)
let api_data = ExternalApi.get_data () in
State.set_encoded ~key:"api_data" ~encode:encode_api_response api_data

(* Client *)
let api_data =
  State.decode
    ~key:"api_data"
    ~decode:decode_api_response
    ~default:default_data
    ()
```

### User Session

```ocaml
(* Server *)
let session = get_current_session req in
State.set_encoded ~key:"session" ~encode:encode_session session

(* Client *)
let session =
  State.decode
    ~key:"session"
    ~decode:decode_session
    ~default:anonymous_session
    ()
```

## Related Documentation

- [solid-ml-ssr/State](../../lib/solid-ml-ssr/state.mli) - Server-side state API
- [solid-ml-browser/State](../../lib/solid-ml-browser/state.mli) - Client-side state API
- [full_ssr_app example](../full_ssr_app/) - Complete SSR with hydration
