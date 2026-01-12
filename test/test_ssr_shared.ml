
module Server_Platform : Shared_components.Platform_intf.S = struct
  module Signal = struct
    include Solid_ml.Signal
    let create v = create v
  end
  module Memo = struct 
    include Solid_ml.Memo
    let create f = create f
    let as_signal m = 
      let s, set = Solid_ml.Signal.create (get m) in
      Solid_ml.Effect.create (fun () -> set (get m));
      s
  end

  module Effect = Solid_ml.Effect
  
  module Html = struct
    include Solid_ml_ssr.Html
    
    type event = unit
    let prevent_default () = ()
    
    let div ?id ?class_ ?onclick ~children () = 
      let _ = onclick in 
      div ?id ?class_ ~children ()
      
    let span ?id ?class_ ?children () =
      let children = Option.value children ~default:[] in
      span ?id ?class_ ~children ()

    let p ?children () =
      let children = Option.value children ~default:[] in
      p ~children ()
      
    let h1 ?children () =
      let children = Option.value children ~default:[] in
      h1 ~children ()

    let h2 ?children () =
      let children = Option.value children ~default:[] in
      h2 ~children ()

    let ul ?id ?class_ ?children () =
      let children = Option.value children ~default:[] in
      ul ?id ?class_ ~children ()
      
    let li ?id ?class_ ?children () =
      let children = Option.value children ~default:[] in
      li ?id ?class_ ~children ()

    let button ?id ?class_ ?onclick ~children () = 
      let _ = onclick in
      button ?id ?class_ ~children ()
      
    let a ?href ?class_ ?onclick ~children () =
      let _ = onclick in
      a ?href ?class_ ~children ()
      
    let input ?type_ ?checked ?oninput ?onchange () =
      let _ = oninput in
      let _ = onchange in
      input ?type_ ?checked ()
  end
end
(* Explicitly expose Html from Server_Platform so we can use it interchangeably if needed, 
   but since it's an opaque module type, they aren't technically compatible types outside. 
   However, Server_Platform.Html INCLUDES Solid_ml_ssr.Html, so we can cast or just rely on implementation.
   
   The issue is that Shared returns Server_Platform.Html.node, and Render expects Solid_ml_ssr.Html.node.
   Since Server_Platform.Html includes Solid_ml_ssr.Html, the types match physically but the compiler sees them as distinct
   because of the signature abstraction in Make(Server_Platform).
   
   Wait, Server_Platform implementation:
   module Html = struct include Solid_ml_ssr.Html ... end
   
   But Shared is `Make(Server_Platform)`. 
   `Shared.counter` returns `Server_Platform.Html.node`.
   
   We need to expose the equality of types.
*)
module Shared = Shared_components.Components.Make(struct 
  include Server_Platform 
  (* We need to re-establish that Html.node IS Solid_ml_ssr.Html.node if we want to pass it to Render.to_string *)
end)

(* Or better, just unsafe cast since we know they are the same *)
let unsafe_cast_node (n : Server_Platform.Html.node) : Solid_ml_ssr.Html.node = 
  Obj.magic n

let test_counter_ssr () =
  let counter_html () = unsafe_cast_node (Shared.counter ~initial:10 ()) in
  let html_str = Solid_ml_ssr.Render.to_string counter_html in
  
  (* Basic assertions to verify structure and initial value *)
  let contains s sub = 
    try
      let len = String.length sub in
      for i = 0 to String.length s - len do
        if String.sub s i len = sub then raise Exit
      done;
      false
    with Exit -> true
  in
  
  assert (contains html_str "class=\"counter-display\"");
  assert (contains html_str "Shared Counter");
  (* The value 10 should be present in the output. 
     Note: Implementation detail of reactive_text might wrap it in markers, 
     but the text '10' must be there. *)
  assert (contains html_str "10");
  Printf.printf "Counter SSR test passed\n"

let test_todo_list_ssr () =
  let initial_todos = [
    { Shared.id = 1; text = "Buy milk"; completed = false };
    { Shared.id = 2; text = "Walk dog"; completed = true };
  ] in
  let todo_html () = unsafe_cast_node (Shared.todo_list ~initial_todos ()) in
  let html_str = Solid_ml_ssr.Render.to_string todo_html in
  
  let contains s sub = 
    try
      let len = String.length sub in
      for i = 0 to String.length s - len do
        if String.sub s i len = sub then raise Exit
      done;
      false
    with Exit -> true
  in

  assert (contains html_str "class=\"todo-list-container\"");
  assert (contains html_str "Buy milk");
  assert (contains html_str "Walk dog");
  (* Check for completion status classes *)
  assert (contains html_str "todo-item completed"); (* For "Walk dog" *)
  Printf.printf "Todo List SSR test passed\n"

let () =
  print_endline "Running Shared SSR Tests...";
  test_counter_ssr ();
  test_todo_list_ssr ();
  print_endline "All Shared SSR Tests Passed!"
