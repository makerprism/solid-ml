(** Browser reactive core tests.
    
    These tests verify the shared reactive implementation works correctly
    when instantiated with the browser backend.
    
    Run with: make browser-tests
    Or directly:
      dune build @test_browser/melange
      node _build/default/test_browser/output/test_browser/test_reactive.js
*)

open Solid_ml_browser
open Reactive_core

(* Note: Hydration and Render modules require DOM APIs and can't be tested in Node.js
   without a DOM polyfill. These tests focus on the reactive core which is pure OCaml. *)

(* Test helpers *)
external console_log : string -> unit = "log" [@@mel.scope "console"]

let set_signal_raw = set_signal
let set_signal s v = ignore (set_signal_raw s v)

let update_signal_raw = update_signal
let update_signal s f = ignore (update_signal_raw s f)

let make_fake_element () : Dom.element =
  [%mel.raw
    {|
      (function() {
        var attrs = Object.create(null);
        var style = {
          _props: Object.create(null),
          setProperty: function(name, value) { this._props[name] = String(value); },
          removeProperty: function(name) { delete this._props[name]; }
        };
        var classList = {
          _set: Object.create(null),
          add: function(name) { this._set[name] = true; },
          remove: function(name) { delete this._set[name]; },
          contains: function(name) { return !!this._set[name]; }
        };
        var el = {
          value: "",
          checked: false,
          className: "",
          style: style,
          classList: classList,
          _handlers: {},
          _attrs: attrs,
          options: [],
          addEventListener: function(name, handler){ this._handlers[name] = handler; },
          removeEventListener: function(name){ delete this._handlers[name]; },
          setAttribute: function(name, value){ this._attrs[name] = String(value); },
          getAttribute: function(name){ return this._attrs[name] || null; },
          removeAttribute: function(name){ delete this._attrs[name]; },
          hasAttribute: function(name){ return this._attrs[name] !== undefined; },
          _style_prop: function(name){ return this.style._props[name] || null; },
          fire: function(name){
            if (this._handlers[name]) {
              this._handlers[name]({ target: this });
            }
          }
        };
        Object.defineProperty(el, "selectedOptions", {
          get: function() {
            return (this.options || []).filter(function(opt){ return !!opt.selected; });
          }
        });
        return el;
      })()
    |}]

let make_fake_select : string array -> Dom.element =
  [%mel.raw
    {|
      function(values){
        var el = (function() {
          var attrs = Object.create(null);
          var style = {
            _props: Object.create(null),
            setProperty: function(name, value) { this._props[name] = String(value); },
            removeProperty: function(name) { delete this._props[name]; }
          };
          var classList = {
            _set: Object.create(null),
            add: function(name) { this._set[name] = true; },
            remove: function(name) { delete this._set[name]; },
            contains: function(name) { return !!this._set[name]; }
          };
          var el = {
            value: "",
            checked: false,
            className: "",
            style: style,
            classList: classList,
            _handlers: {},
            _attrs: attrs,
            options: [],
            addEventListener: function(name, handler){ this._handlers[name] = handler; },
            removeEventListener: function(name){ delete this._handlers[name]; },
            setAttribute: function(name, value){ this._attrs[name] = String(value); },
            getAttribute: function(name){ return this._attrs[name] || null; },
            removeAttribute: function(name){ delete this._attrs[name]; },
            hasAttribute: function(name){ return this._attrs[name] !== undefined; },
            _style_prop: function(name){ return this.style._props[name] || null; },
            fire: function(name){
              if (this._handlers[name]) {
                this._handlers[name]({ target: this });
              }
            }
          };
          Object.defineProperty(el, "selectedOptions", {
            get: function() {
              return (this.options || []).filter(function(opt){ return !!opt.selected; });
            }
          });
          return el;
        })();
        for (var i = 0; i < values.length; i++) {
          el.options.push({ value: String(values[i]), selected: false });
        }
        return el;
      }
    |}]

external fire_event : Dom.element -> string -> unit = "fire" [@@mel.send]

external element_style_prop : Dom.element -> string -> string option = "_style_prop"
  [@@mel.send]

let passed = ref 0
let failed = ref 0

let test name fn =
  console_log ("Test: " ^ name);
  try
    fn ();
    incr passed;
    console_log "  PASSED"
  with exn ->
    incr failed;
    console_log ("  FAILED: " ^ Printexc.to_string exn)

let assert_eq a b =
  if a <> b then failwith "assertion failed: values not equal"

let assert_true b =
  if not b then failwith "assertion failed: expected true"

(* Ensure we have a runtime for tests *)
let with_runtime f =
  let (_, dispose) = create_root (fun () -> f ()) in
  dispose ()

(* ============ Signal Tests ============ *)

let test_signal_basic () =
  test "Signal basic operations" (fun () ->
    with_runtime (fun () ->
      let s = create_signal 42 in
      assert_eq (get_signal s) 42;
      set_signal s 100;
      assert_eq (get_signal s) 100
    )
  )

let test_signal_peek () =
  test "Signal.peek doesn't track" (fun () ->
    with_runtime (fun () ->
      let s = create_signal 1 in
      let runs = ref 0 in
      create_effect (fun () ->
        incr runs;
        let _ = peek_signal s in  (* Should not track *)
        ()
      );
      assert_eq !runs 1;
      set_signal s 2;
      (* Effect should NOT re-run because we used peek *)
      assert_eq !runs 1
    )
  )

let test_signal_equality () =
  test "Signal skips update on equal value" (fun () ->
    with_runtime (fun () ->
      let s = create_signal 1 in
      let runs = ref 0 in
      create_effect (fun () ->
        incr runs;
        let _ = get_signal s in
        ()
      );
      assert_eq !runs 1;
      set_signal s 1;  (* Same value *)
      assert_eq !runs 1;  (* Should not re-run *)
      set_signal s 2;  (* Different value *)
      assert_eq !runs 2  (* Should re-run *)
    )
  )

(* ============ Effect Tests ============ *)

let test_effect_tracking () =
  test "Effect auto-tracks dependencies" (fun () ->
    with_runtime (fun () ->
      let s = create_signal 0 in
      let observed = ref (-1) in
      create_effect (fun () ->
        observed := get_signal s
      );
      assert_eq !observed 0;
      set_signal s 5;
      assert_eq !observed 5
    )
  )

let test_effect_cleanup () =
  test "Effect cleanup runs before re-execution" (fun () ->
    with_runtime (fun () ->
      let s = create_signal 0 in
      let log = ref [] in
      create_effect_with_cleanup (fun () ->
        log := ("run " ^ string_of_int (get_signal s)) :: !log;
        fun () -> log := "cleanup" :: !log
      );
      assert_eq !log ["run 0"];
      set_signal s 1;
      assert_eq !log ["run 1"; "cleanup"; "run 0"]
    )
  )

let test_effect_untrack () =
  test "Effect.untrack prevents tracking" (fun () ->
    with_runtime (fun () ->
      let s1 = create_signal 1 in
      let s2 = create_signal 2 in
      let runs = ref 0 in
      create_effect (fun () ->
        incr runs;
        let _ = get_signal s1 in
        let _ = untrack (fun () -> get_signal s2) in
        ()
      );
      assert_eq !runs 1;
      set_signal s1 10;
      assert_eq !runs 2;  (* s1 is tracked *)
      set_signal s2 20;
      assert_eq !runs 2   (* s2 is NOT tracked *)
    )
  )

(* ============ Memo Tests ============ *)

let test_memo_basic () =
  test "Memo caches derived values" (fun () ->
    with_runtime (fun () ->
      let s = create_signal 2 in
      let runs = ref 0 in
      let doubled = create_memo (fun () ->
        incr runs;
        get_signal s * 2
      ) in
      assert_eq (get_memo doubled) 4;
      assert_eq !runs 1;
      (* Reading again should not recompute *)
      assert_eq (get_memo doubled) 4;
      assert_eq !runs 1;
      (* Changing source should recompute *)
      set_signal s 5;
      assert_eq (get_memo doubled) 10;
      assert_eq !runs 2
    )
  )

let test_memo_chain () =
  test "Memos can depend on other memos" (fun () ->
    with_runtime (fun () ->
      let s = create_signal 1 in
      let m1 = create_memo (fun () -> get_signal s + 1) in
      let m2 = create_memo (fun () -> get_memo m1 * 2) in
      assert_eq (get_memo m2) 4;  (* (1+1)*2 *)
      set_signal s 5;
      assert_eq (get_memo m2) 12  (* (5+1)*2 *)
    )
  )

(* ============ Selector Tests ============ *)

let test_selector_simple () =
  test "create_selector simple selection" (fun () ->
    with_runtime (fun () ->
      let selected = create_signal (-1) in
      let is_selected = Reactive.create_selector selected in
      let count = ref 0 in
      let list = Array.init 100 (fun i ->
        create_memo (fun () ->
          incr count;
          if is_selected i then "selected" else "no"
        )
      ) in
      assert_eq !count 100;
      assert_eq (get_memo list.(3)) "no";
      count := 0;
      set_signal selected 3;
      assert_eq !count 1;
      assert_eq (get_memo list.(3)) "selected";
      count := 0;
      set_signal selected 6;
      assert_eq !count 2;
      assert_eq (get_memo list.(3)) "no";
      assert_eq (get_memo list.(6)) "selected";
      count := 0;
      set_signal selected (-1);
      assert_eq !count 1;
      assert_eq (get_memo list.(6)) "no";
      count := 0;
      set_signal selected 5;
      assert_eq !count 1;
      assert_eq (get_memo list.(5)) "selected"
    )
  )

let test_selector_double () =
  test "create_selector double selection" (fun () ->
    with_runtime (fun () ->
      let selected = create_signal (-1) in
      let is_selected = Reactive.create_selector selected in
      let count = ref 0 in
      let list = Array.init 100 (fun i ->
        ( create_memo (fun () ->
            incr count;
            if is_selected i then "selected" else "no"
          ),
          create_memo (fun () ->
            incr count;
            if is_selected i then "oui" else "non"
          )
        )
      ) in
      assert_eq !count 200;
      assert_eq (get_memo (fst list.(3))) "no";
      assert_eq (get_memo (snd list.(3))) "non";
      count := 0;
      set_signal selected 3;
      assert_eq !count 2;
      assert_eq (get_memo (fst list.(3))) "selected";
      assert_eq (get_memo (snd list.(3))) "oui";
      count := 0;
      set_signal selected 6;
      assert_eq !count 4;
      assert_eq (get_memo (fst list.(3))) "no";
      assert_eq (get_memo (snd list.(3))) "non";
      assert_eq (get_memo (fst list.(6))) "selected";
      assert_eq (get_memo (snd list.(6))) "oui"
    )
  )

let test_selector_zero_index () =
  test "create_selector zero index" (fun () ->
    with_runtime (fun () ->
      let selected = create_signal (-1) in
      let is_selected = Reactive.create_selector selected in
      let count = ref 0 in
      let list = [|
        create_memo (fun () ->
          incr count;
          if is_selected 0 then "selected" else "no"
        )
      |] in
      assert_eq !count 1;
      assert_eq (get_memo list.(0)) "no";
      count := 0;
      set_signal selected 0;
      assert_eq !count 1;
      assert_eq (get_memo list.(0)) "selected";
      count := 0;
      set_signal selected (-1);
      assert_eq !count 1;
      assert_eq (get_memo list.(0)) "no"
    )
  )

(* ============ Owner Tests ============ *)

let test_owner_cleanup () =
  test "Owner.on_cleanup runs on dispose" (fun () ->
    with_runtime (fun () ->
      let cleaned = ref false in
      let (_, dispose) = create_root (fun () ->
        on_cleanup (fun () -> cleaned := true)
      ) in
      assert_true (not !cleaned);
      dispose ();
      assert_true !cleaned
    )
  )

let test_nested_roots () =
  test "Nested roots dispose children" (fun () ->
    with_runtime (fun () ->
      let order = ref [] in
      let (_, dispose_outer) = create_root (fun () ->
        on_cleanup (fun () -> order := "outer" :: !order);
        let (_, _dispose_inner) = create_root (fun () ->
          on_cleanup (fun () -> order := "inner" :: !order)
        ) in
        ()
      ) in
      dispose_outer ();
      (* Inner should be disposed before outer *)
      assert_eq !order ["outer"; "inner"]
    )
  )

(* ============ Context Tests ============ *)

let test_context_basic () =
  test "Context basic provide/use" (fun () ->
    with_runtime (fun () ->
      let ctx = create_context "default" in
      assert_eq (use_context ctx) "default";
      let result = provide_context ctx "provided" (fun () ->
        use_context ctx
      ) in
      assert_eq result "provided";
      (* Outside provide, back to default *)
      assert_eq (use_context ctx) "default"
    )
  )

let test_context_nesting () =
  test "Context nested provides" (fun () ->
    with_runtime (fun () ->
      let ctx = create_context "L0" in
      provide_context ctx "L1" (fun () ->
        assert_eq (use_context ctx) "L1";
        provide_context ctx "L2" (fun () ->
          assert_eq (use_context ctx) "L2"
        );
        assert_eq (use_context ctx) "L1"
      )
    )
  )

(* ============ DOM Bindings Tests ============ *)

let test_bind_input () =
  test "Reactive.bind_input syncs value" (fun () ->
    with_runtime (fun () ->
      let el = make_fake_element () in
      let signal = create_signal "A" in
      Reactive.bind_input el signal (fun v -> set_signal signal v);
      assert_eq (Dom.element_value el) "A";
      Dom.element_set_value el "B";
      fire_event el "input";
      assert_eq (get_signal signal) "B";
      set_signal signal "C";
      assert_eq (Dom.element_value el) "C"
    )
  )

let test_bind_checkbox () =
  test "Reactive.bind_checkbox syncs checked" (fun () ->
    with_runtime (fun () ->
      let el = make_fake_element () in
      let signal = create_signal false in
      Reactive.bind_checkbox el signal (fun v -> set_signal signal v);
      assert_true (Dom.element_checked el = false);
      Dom.element_set_checked el true;
      fire_event el "change";
      assert_true (get_signal signal);
      set_signal signal false;
      assert_true (Dom.element_checked el = false)
    )
  )

let test_bind_attr () =
  test "Reactive.bind_attr updates attributes" (fun () ->
    with_runtime (fun () ->
      let el = make_fake_element () in
      let signal = create_signal "start" in
      Reactive.bind_attr el "data-kind" signal;
      (match Dom.get_attribute el "data-kind" with
       | Some v -> assert_eq v "start"
       | None -> failwith "expected attribute to be set");
      set_signal signal "next";
      (match Dom.get_attribute el "data-kind" with
       | Some v -> assert_eq v "next"
       | None -> failwith "expected attribute to be updated")
    )
  )

let test_bind_attr_opt () =
  test "Reactive.bind_attr_opt adds/removes attributes" (fun () ->
    with_runtime (fun () ->
      let el = make_fake_element () in
      let signal = create_signal (Some "on") in
      Reactive.bind_attr_opt el "data-flag" signal;
      (match Dom.get_attribute el "data-flag" with
       | Some v -> assert_eq v "on"
       | None -> failwith "expected attribute to be set");
      set_signal signal None;
      assert_true (Dom.get_attribute el "data-flag" = None)
    )
  )

let test_bind_class_toggle () =
  test "Reactive.bind_class_toggle toggles class" (fun () ->
    with_runtime (fun () ->
      let el = make_fake_element () in
      let signal = create_signal false in
      Reactive.bind_class_toggle el "active" signal;
      assert_true (not (Dom.has_class el "active"));
      set_signal signal true;
      assert_true (Dom.has_class el "active");
      set_signal signal false;
      assert_true (not (Dom.has_class el "active"))
    )
  )

let test_bind_style () =
  test "Reactive.bind_style updates style" (fun () ->
    with_runtime (fun () ->
      let el = make_fake_element () in
      let signal = create_signal "red" in
      Reactive.bind_style el "color" signal;
      (match element_style_prop el "color" with
       | Some v -> assert_eq v "red"
       | None -> failwith "expected style to be set");
      set_signal signal "blue";
      (match element_style_prop el "color" with
       | Some v -> assert_eq v "blue"
       | None -> failwith "expected style to be updated")
    )
  )

let test_bind_select_multiple () =
  test "Reactive.bind_select_multiple syncs selection" (fun () ->
    with_runtime (fun () ->
      let el = make_fake_select [| "a"; "b"; "c" |] in
      let signal = create_signal ["a"; "c"] in
      Reactive.bind_select_multiple el signal (fun v -> set_signal signal v);
      assert_eq (Array.to_list (Dom.element_selected_values el)) ["a"; "c"];
      Dom.element_set_selected_values el [| "b" |];
      fire_event el "change";
      assert_eq (get_signal signal) ["b"];
      set_signal signal ["a"];
      assert_eq (Array.to_list (Dom.element_selected_values el)) ["a"]
    )
  )


(* ============ Batch Tests ============ *)

let test_batch_updates () =
  test "Batch groups updates" (fun () ->
    with_runtime (fun () ->
      let s1 = create_signal 0 in
      let s2 = create_signal 0 in
      let runs = ref 0 in
      create_effect (fun () ->
        incr runs;
        let _ = get_signal s1 + get_signal s2 in
        ()
      );
      assert_eq !runs 1;
      batch (fun () ->
        set_signal s1 1;
        set_signal s2 2
      );
      (* Effect should only run once for the batch *)
      assert_eq !runs 2
    )
  )

(* ============ Diamond Dependency ============ *)

let test_diamond () =
  test "Diamond dependency (glitch-free)" (fun () ->
    with_runtime (fun () ->
      let a = create_signal 1 in
      let b = create_memo (fun () -> get_signal a * 2) in
      let c = create_memo (fun () -> get_signal a * 3) in
      let d_runs = ref 0 in
      let d = create_memo (fun () ->
        incr d_runs;
        get_memo b + get_memo c
      ) in
      assert_eq (get_memo d) 5;
      let initial_runs = !d_runs in
      set_signal a 2;
      assert_eq (get_memo d) 10;
      (* d should only compute once per change *)
      assert_true (!d_runs <= initial_runs + 1)
    )
  )

(* ============ Run All Tests ============ *)

let () =
  console_log "\n=== Browser Reactive Tests ===\n";
  
  console_log "-- Signal Tests --";
  test_signal_basic ();
  test_signal_peek ();
  test_signal_equality ();
  
  console_log "\n-- Effect Tests --";
  test_effect_tracking ();
  test_effect_cleanup ();
  test_effect_untrack ();
  
  console_log "\n-- Memo Tests --";
  test_memo_basic ();
  test_memo_chain ();

  console_log "\n-- Selector Tests --";
  test_selector_simple ();
  test_selector_double ();
  test_selector_zero_index ();
  
  console_log "\n-- Owner Tests --";
  test_owner_cleanup ();
  test_nested_roots ();
  
  console_log "\n-- Context Tests --";
  test_context_basic ();
  test_context_nesting ();
  
  console_log "\n-- Batch Tests --";
  test_batch_updates ();

  console_log "\n-- DOM Binding Tests --";
  test_bind_input ();
  test_bind_checkbox ();
  test_bind_attr ();
  test_bind_attr_opt ();
  test_bind_class_toggle ();
  test_bind_style ();
  test_bind_select_multiple ();

  console_log "\n-- Integration Tests --";
  test_diamond ();
  
  console_log "\n=== Results ===";
  console_log ("Passed: " ^ string_of_int !passed);
  console_log ("Failed: " ^ string_of_int !failed);
  
  if !failed > 0 then
    console_log "\n*** SOME TESTS FAILED ***"
  else
    console_log "\n=== All browser tests passed! ==="
