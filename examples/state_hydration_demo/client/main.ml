(** Client-side example demonstrating State module usage.

    This example shows how to:
    1. Retrieve server state using State.decode
    2. Use the state during hydration

    This would typically be run in a browser after the server-rendered
    HTML is loaded. The window.__SOLID_ML_DATA__ object contains
    the serialized state from the server.
*)

open Solid_ml_browser

module C = State_hydration_shared.Components

(** {1 Component Functions} *)

let counter_component ~(initial : int) =
  let count, _set_count = Reactive.Signal.create initial in
  Html.(
    div ~class_:"counter-demo" ~children:[
      h2 ~children:[text "Server→Client State Transfer"] ();
      p ~children:[text "The counter value was set on the server and transferred to the client."] ();

      div ~class_:"counter" ~children:[
        text "Count: ";
        Html.reactive_text count;
      ] ();

      p ~class_:"note" ~children:[text "Initial value came from server State module"] ();
    ] ()
  )

let user_profile_component ~(user : C.user) =
  Html.(
    div ~class_:"user-profile" ~children:[
      h2 ~children:[text "User Profile (Server Data)"] ();
      p ~children:[text "User data was serialized on the server and hydrated on the client."] ();

      div ~class_:"user-card" ~children:[
        div ~class_:"user-field" ~children:[
          span ~class_:"label" ~children:[text "Name:"] ();
          span ~class_:"value" ~children:[text user.C.name] ();
        ] ();
        div ~class_:"user-field" ~children:[
          span ~class_:"label" ~children:[text "ID:"] ();
          span ~class_:"value" ~children:[text (string_of_int user.C.id)] ();
        ] ();
        div ~class_:"user-field" ~children:[
          span ~class_:"label" ~children:[text "Email:"] ();
          span ~class_:"value" ~children:[text user.email] ();
        ] ();
      ] ();

      p ~class_:"note" ~children:[text "All user data came from server via State module"] ();
    ] ()
  )

let cart_component ~(items : C.cart_item list) =
  let total = List.fold_left (fun acc item -> acc +. (item.C.price *. float_of_int item.C.quantity)) 0.0 items in
  Html.(
    div ~class_:"cart-demo" ~children:[
      h2 ~children:[text "Shopping Cart (Server Data)"] ();
      p ~children:[text "Cart items were serialized on the server and transferred to the client."] ();

      div ~class_:"cart-items" ~children:(
        List.map (fun item ->
          div ~class_:"cart-item" ~children:[
            span ~class_:"item-name" ~children:[text item.C.name] ();
            span ~class_:"item-details" ~children:[
              text (Printf.sprintf "%d x $%.2f" item.C.quantity item.C.price);
            ] ();
            span ~class_:"item-total" ~children:[
              text (Printf.sprintf "$%.2f" (item.C.price *. float_of_int item.C.quantity));
            ] ();
          ] ()
        ) items
      ) ();

      div ~class_:"cart-total" ~children:[
        text "Total: ";
        text (Printf.sprintf "$%.2f" total);
      ] ();

      p ~class_:"note" ~children:[text "Cart data transferred from server via State.encode_list"] ();
    ] ()
  )

(** {1 Decoders} *)

let decode_int json =
  match Js.Json.decodeNumber json with
  | Some n -> Some (int_of_float n)
  | None -> None

let decode_user json : C.user option =
  match Js.Json.decodeObject json with
  | None -> None
  | Some obj ->
    let name = Js.Dict.get obj "name" in
    let id = Js.Dict.get obj "id" in
    let email = Js.Dict.get obj "email" in
    match (name, id, email) with
    | (Some n, Some i, Some e) ->
      begin match Js.Json.decodeString n, decode_int i, Js.Json.decodeString e with
      | (Some name_str, Some id_int, Some email_str) ->
        Some { C.name = name_str; id = id_int; email = email_str }
      | _ -> None
      end
    | _ -> None

let decode_cart_item json : C.cart_item option =
  match Js.Json.decodeObject json with
  | None -> None
  | Some obj ->
    let id = Js.Dict.get obj "id" in
    let name = Js.Dict.get obj "name" in
    let price = Js.Dict.get obj "price" in
    let quantity = Js.Dict.get obj "quantity" in
    match (id, name, price, quantity) with
    | (Some i, Some n, Some p, Some q) ->
      begin match decode_int i, Js.Json.decodeString n, Js.Json.decodeNumber p, decode_int q with
      | (Some id_int, Some name_str, Some price_float, Some qty_int) ->
        Some { C.id = id_int; name = name_str; price = price_float; quantity = qty_int }
      | _ -> None
      end
    | _ -> None

(** {1 Hydration Functions} *)

let has_hydrated = ref false

let render_app app_el component =
  let render = if !has_hydrated then Render.render else Render.hydrate in
  let _disposer = render app_el component in
  has_hydrated := true

let hydrate_counter () =
  match Dom.get_element_by_id (Dom.document ()) "app" with
  | Some app_el ->
    let counter_key = State.key ~namespace:"demo" "counter" in
    let initial =
      State.decode
        ~key:counter_key
        ~decode:decode_int
        ~default:0
    in

    Dom.log ("Counter initial value from server: " ^ string_of_int initial);

    render_app app_el (fun () -> counter_component ~initial);

    Dom.log "Counter hydrated!"
  | None -> ()

let hydrate_user_profile () =
  match Dom.get_element_by_id (Dom.document ()) "app" with
  | Some app_el ->
    let user_key = State.key ~namespace:"demo" "user" in
    let user =
      State.decode
        ~key:user_key
        ~decode:decode_user
        ~default:{ C.name = "Guest"; id = 0; email = "guest@example.com" }
    in

    Dom.log ("User from server: " ^ user.name);
    Dom.log ("User ID: " ^ string_of_int user.id);
    Dom.log ("User email: " ^ user.email);

    render_app app_el (fun () -> user_profile_component ~user);

    Dom.log "User profile hydrated!"
  | None -> ()

let hydrate_cart () =
  match Dom.get_element_by_id (Dom.document ()) "app" with
  | Some app_el ->
    let cart_key = State.key ~namespace:"demo" "cart" in

    (* Decode the array of cart items *)
    let decode_cart_array json =
      match Js.Json.decodeArray json with
      | None -> None
      | Some arr ->
        let items = Array.fold_right (fun item acc ->
          match decode_cart_item item with
          | Some i -> i :: acc
          | None -> acc
        ) arr [] in
        Some items
    in

    let items =
      State.decode
        ~key:cart_key
        ~decode:decode_cart_array
        ~default:[]
    in

    Dom.log ("Cart items from server: " ^ string_of_int (List.length items));
    List.iter (fun item ->
      Dom.log ("  - " ^ item.C.name ^ " x" ^ string_of_int item.C.quantity)
    ) items;

    render_app app_el (fun () -> cart_component ~items);

    Dom.log "Cart hydrated!"
  | None -> ()

(** {1 Main Entry Point} *)

(* In a real application, you'd detect which page to hydrate based on the URL.
   For this demo, we hydrate all components to show the API usage.
*)

let () =
  Dom.log "State Hydration Demo - Client Side";
  Dom.log "====================================";
  Dom.log "";
  Dom.log "The server should have set window.__SOLID_ML_DATA__ with the state.";
  Dom.log "We'll now retrieve and use that state for hydration.";
  Dom.log "";

  (* Try to hydrate each component *)
  hydrate_counter ();
  hydrate_user_profile ();
  hydrate_cart ();

  (* Show what's in window.__SOLID_ML_DATA__ *)
  match Js.Nullable.toOption (Dom.get_hydration_data ()) with
  | Some data ->
    Dom.log "State data retrieved successfully!";
    (match Js.Json.decodeObject data with
     | Some obj ->
       Dom.log "Keys in state:";
       Js.Dict.keys obj |> Array.iter (fun key ->
         Dom.log ("  - " ^ key)
       )
     | None -> Dom.log "State is not a valid object")
  | None -> Dom.log "No state data found - server may not have set it"
