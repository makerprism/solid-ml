(** Server-side example demonstrating State module usage.

    This example shows how to:
    1. Store server state using State.set_encoded
    2. Render components to HTML
    3. Generate the hydration script with Render.get_hydration_script()

    Run with: dune exec examples/state_hydration_demo/server/main.exe
*)

open Solid_ml_ssr

module C = State_hydration_shared.Components

(** {1 Component Functions} *)

let counter_component ~(initial : int) =
  let count, _set_count = Solid_ml.Signal.create initial in
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

(** Sample data - in a real app this would come from a database or API *)
let sample_user = {
  C.name = "Alice Johnson";
  id = 42;
  email = "alice@example.com";
}

let sample_cart_items = [
  { C.id = 1; name = "Mechanical Keyboard"; price = 150.00; quantity = 1 };
  { C.id = 2; name = "USB-C Cable"; price = 12.50; quantity = 3 };
  { C.id = 3; name = "Mouse Pad"; price = 25.00; quantity = 1 };
]

(** {1 Page Layout} *)

let layout ~title:page_title ~children () =
  Html.(
    html ~lang:"en" ~children:[
      head ~children:[
        meta ~charset:"utf-8" ();
        meta ~name:"viewport" ~content:"width=device-width, initial-scale=1" ();
        title ~children:[text page_title] ();
        raw {|<style>
          * { box-sizing: border-box; }
          body {
            font-family: system-ui, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
          }
          .container {
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
          }
          h1 {
            color: #333;
            border-bottom: 2px solid #4a90d9;
            padding-bottom: 10px;
          }
          h2 {
            color: #4a5568;
            margin-top: 25px;
          }
          .counter {
            font-size: 32px;
            font-weight: bold;
            text-align: center;
            padding: 20px;
            background: #f0f0f0;
            border-radius: 8px;
            margin: 15px 0;
          }
          .user-card {
            background: #f9fafb;
            padding: 20px;
            border-radius: 8px;
            border: 1px solid #e5e7eb;
          }
          .user-field {
            display: flex;
            padding: 8px 0;
            border-bottom: 1px solid #e5e7eb;
          }
          .user-field:last-child {
            border-bottom: none;
          }
          .label {
            font-weight: bold;
            width: 80px;
            color: #374151;
          }
          .value {
            color: #6b7280;
          }
          .cart-items {
            margin: 15px 0;
          }
          .cart-item {
            display: flex;
            justify-content: space-between;
            padding: 12px;
            background: #f9fafb;
            border-radius: 4px;
            margin-bottom: 8px;
          }
          .item-name {
            font-weight: bold;
          }
          .item-details {
            color: #6b7280;
          }
          .item-total {
            font-weight: bold;
            color: #4a90d9;
          }
          .cart-total {
            font-size: 20px;
            font-weight: bold;
            text-align: right;
            padding: 15px;
            background: #f0f0f0;
            border-radius: 8px;
          }
          .note {
            font-style: italic;
            color: #6b7280;
            font-size: 14px;
            margin-top: 15px;
          }
          hr {
            border: none;
            border-top: 1px solid #e5e7eb;
            margin: 30px 0;
          }
        </style>|};
      ] ();
      body ~children:[
        div ~class_:"container" ~children:[
          h1 ~children:[text "State Hydration Demo"] ();
          p ~children:[text "This page demonstrates the solid-ml State module for server→client state transfer."] ();
          children
        ] ()
      ] ()
    ] ()
  )

(** {1 Pages} *)

let counter_page ~initial () =
  layout ~title:"Counter - State Hydration Demo" ~children:(
    counter_component ~initial
  ) ()

let user_profile_page ~user () =
  layout ~title:"User Profile - State Hydration Demo" ~children:(
    user_profile_component ~user
  ) ()

let cart_page ~items () =
  layout ~title:"Shopping Cart - State Hydration Demo" ~children:(
    cart_component ~items
  ) ()

(** {1 Main: Generate HTML with State Script} *)

let () =
  (* Generate counter page *)
  let counter_key = State.key ~namespace:"demo" "counter" in

  Printf.printf "=== Generating Counter Page ===\n\n";
  State.set_encoded ~key:counter_key ~encode:State.encode_int 100;
  let counter_html = Render.to_document (fun () ->
    counter_page ~initial:100 ()
  ) in
  let counter_script = Render.get_hydration_script () in

  Printf.printf "%s\n\n" counter_html;
  Printf.printf "State script (include this before closing </body>):\n";
  Printf.printf "%s\n\n" counter_script;

  (* Generate user profile page *)
  let user_key = State.key ~namespace:"demo" "user" in

  Printf.printf "=== Generating User Profile Page ===\n\n";
  let encode_user (user : C.user) =
    State.encode_object [
      ("name", State.encode_string user.name);
      ("id", State.encode_int user.id);
      ("email", State.encode_string user.email);
    ]
  in
  State.set_encoded ~key:user_key ~encode:encode_user sample_user;
  let user_html = Render.to_document (fun () ->
    user_profile_page ~user:sample_user ()
  ) in
  let user_script = Render.get_hydration_script () in

  Printf.printf "%s\n\n" user_html;
  Printf.printf "State script (include this before closing </body>):\n";
  Printf.printf "%s\n\n" user_script;

  (* Generate cart page *)
  let cart_key = State.key ~namespace:"demo" "cart" in

  Printf.printf "=== Generating Shopping Cart Page ===\n\n";
  let encode_cart_item (item : C.cart_item) =
    State.encode_object [
      ("id", State.encode_int item.id);
      ("name", State.encode_string item.name);
      ("price", State.encode_float item.price);
      ("quantity", State.encode_int item.quantity);
    ]
  in
  State.set_encoded
    ~key:cart_key
    ~encode:State.encode_list
    (List.map encode_cart_item sample_cart_items);
  let cart_html = Render.to_document (fun () ->
    cart_page ~items:sample_cart_items ()
  ) in
  let cart_script = Render.get_hydration_script () in

  Printf.printf "%s\n\n" cart_html;
  Printf.printf "State script (include this before closing </body>):\n";
  Printf.printf "%s\n\n" cart_script;

  (* Show what the serialized state looks like *)
  Printf.printf "=== Serialized State (JSON) ===\n";
  State.set_encoded ~key:counter_key ~encode:State.encode_int 100;
  State.set_encoded ~key:user_key ~encode:encode_user sample_user;
  State.set_encoded ~key:cart_key ~encode:State.encode_list (List.map encode_cart_item sample_cart_items);
  Printf.printf "%s\n" (State.to_json ())
