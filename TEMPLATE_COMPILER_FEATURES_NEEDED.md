# Template Compiler Feature Gaps: solid-ml vs SolidJS

## Summary

The solid-ml reactive runtime (Signals, Effects, Memos, Context, etc.) is feature-complete and competitive with SolidJS. However, the **template compiler (`.mlx` files)** has significant gaps that make it impossible to implement common UI patterns like:

- Multi-step forms with validation
- Conditional rendering based on signal values
- Two-way form bindings
- Dynamic attribute/class bindings

## Current State

### What Works ✅

The template compiler currently supports:

```ocaml
(* Reactive text *)
(Tpl.text (fun () -> Int.to_string (Signal.get count)))

(* Reactive lists with keys *)
(Tpl.each_keyed
   ~items:(fun () -> Signal.get items)
   ~key:(fun item -> item.id)
   ~render:(fun item -> <li>(text item.name)</li>))

(* Static onclick handlers *)
<button onclick=(fun _ -> Signal.update count (fun n -> n + 1))>
```

### What Doesn't Work ❌

```ocaml
(* ❌ Conditional rendering based on signal - NOT SUPPORTED *)
(match Signal.get step with
 | Welcome -> welcome_step ()
 | PersonalInfo -> personal_step ()
 | _ -> other_step ())

(* ❌ Two-way form binding - NOT SUPPORTED *)
<input
  type_="text"
  value=Signal.get name
  oninput=(fun ev -> set_name (Dom.element_value ev)) />

(* ❌ Dynamic attributes based on signals - NOT SUPPORTED *)
<div class_=("step-" ^ Signal.get current_step)>

(* ❌ Show/hide based on signal - NOT SUPPORTED *)
(Tpl.show (fun () -> Signal.get is_visible) ...)
```

## Feature Comparison

| Feature | SolidJS | solid-ml Browser | solid-ml Template (.mlx) |
|---------|---------|------------------|--------------------------|
| Reactive text | ✅ | ✅ | ✅ `Tpl.text` |
| Reactive lists | ✅ | ✅ | ✅ `Tpl.each_keyed` |
| Conditional rendering | ✅ `<Show>` | ✅ `Reactive.if_`, `Reactive.show` | ❌ MISSING |
| Two-way input binding | ✅ `bind:value` | ✅ `Reactive.bind_input` | ❌ MISSING |
| Dynamic classes | ✅ `classList:` | ✅ `Reactive.bind_class` | ⚠️ `Tpl.class_list` (limited) |
| Dynamic attributes | ✅ | ✅ `Reactive.bind_attr` | ⚠️ `Tpl.attr` (limited) |
| Index/For loops | ✅ `<Index>` | ✅ `Reactive.each` | ❌ MISSING |
| Suspense/Error boundaries | ✅ | ✅ | ❌ MISSING |

## Concrete Examples

### Example 1: Multi-Step Wizard Form

**What we want to write:**

```ocaml
let view () =
  let step, set_step = Signal.create Welcome in
  let form, set_form = Signal.create initial_form in

  <div>
    (* Progress bar - conditional classes based on step *)
    <div class_=("progress-step" ^ (if Signal.get step = 1 then " active" else ""))>

    (* Conditional rendering based on step *)
    (Tpl.show_when
       ~when_:(fun () -> Signal.get step = Welcome)
       ~render:(fun () -> welcome_step ()))

    (Tpl.show_when
       ~when_:(fun () -> Signal.get step = PersonalInfo)
       ~render:(fun () ->
         <input
           type_="text"
           (* Two-way binding *)
           Tpl.bind_input ~signal:(fun () -> Signal.get form.personal.name)
           ~setter:(fun name -> set_form {...form with personal = {...form.personal with name}}) />))

    (* Navigation buttons *)
    <button
      disabled=(Signal.get step = Complete)
      onclick=(fun _ -> set_step (next_step (Signal.get step)))>
  </div>
```

**What we're forced to write instead:**

```ocaml
(* ❌ This doesn't work - Signal.get is not tracked outside Tpl.* *)
let view () =
  let form, _set_form = Signal.create initial_form in
  let current = Signal.get form in  (* Only reads ONCE *)

  (* No way to conditionally render based on signal *)
  (* No way to bind input values *)
  (* Have to use manual DOM manipulation in client.ml *)
```

### Example 2: Todo List with Filters

**SolidJS:**

```jsx
<Show when={filter() === 'all'}>
  <For each={todos()}>{todo => <TodoItem todo={todo} />}</For>
</Show>
<Show when={filter() === 'active'}>
  <For each={activeTodos()}>{todo => <TodoItem todo={todo} />}</For>
</Show>
```

**solid-ml (desired):**

```ocaml
(Tpl.show_when
   ~when_:(fun () -> Signal.get filter = "all")
   ~render:(fun () ->
     (Tpl.each_keyed
        ~items:(fun () -> Signal.get todos)
        ~key:(fun t -> t.id)
        ~render:todo_item)))
```

**solid-ml (current - doesn't work):**

```ocaml
(* Can't conditionally render lists *)
(* Can't filter reactively *)
(* Must render all items and use CSS to hide - inefficient *)
```

## Required Template Compiler Additions

### 1. Conditional Rendering

```ocaml
module Tpl : sig
  (** Show/hide based on boolean signal *)
  val show_when :
    when_:(unit -> bool) ->
    render:(unit -> Html.node) ->
    Html.node

  (** Render one of two branches based on condition *)
  val if_ :
    when_:(unit -> bool) ->
    then_:(unit -> Html.node) ->
    else_:(unit -> Html.node) ->
    Html.node

  (** Match on variant type (like pattern matching Show) *)
  val switch :
    match_:(unit -> 'a) ->
    cases:[| ('a -> bool) * (unit -> Html.node) |] ->
    Html.node
end
```

**Implementation hint:** The browser backend already has `Reactive.show` and `Reactive.if_` - the template compiler just needs to expose them via the Tpl interface.

### 2. Form Bindings

```ocaml
module Tpl : sig
  (** Two-way binding for text inputs *)
  val bind_input :
    signal:(unit -> string) ->
    setter:(string -> unit) ->
    Html.attr

  (** Two-way binding for checkboxes *)
  val bind_checkbox :
    signal:(unit -> bool) ->
    setter:(bool -> unit) ->
    Html.attr

  (** Two-way binding for select/option *)
  val bind_select :
    signal:(unit -> string) ->
    setter:(string -> unit) ->
    Html.attr
end
```

**Usage:**

```ocaml
<input
  type_="text"
  Tpl.bind_input ~signal:(fun () -> Signal.get name) ~setter:set_name />

<input
  type_="checkbox"
  Tpl.bind_checkbox ~signal:(fun () -> Signal.get checked) ~setter:set_checked />
```

**Implementation hint:** Browser backend has `Reactive.bind_input`, `Reactive.bind_checkbox` - need to wire these into template compiler's attribute handling.

### 3. Dynamic Attribute Values

**Problem:** Currently, attribute values are computed once at render time:

```ocaml
(* This only evaluates once - NOT reactive *)
<div class_=("step-" ^ step_number)>
```

**Solution:** Allow reactive expressions in attributes:

```ocaml
(* Should re-evaluate when step changes *)
<div class_=Tpl.attr_value (fun () -> "step-" ^ Signal.get step_number)>
```

Or use a helper:

```ocaml
<div Tpl.class_list=[("active", fun () -> Signal.get is_active)]>
```

### 4. Index/For Loops (Non-Keyed Iteration)

SolidJS has `<Index>` for index-based iteration (when keys aren't stable):

```ocaml
module Tpl : sig
  (** Iterate by index (re-renders entire list on change) *)
  val each :
    items:(unit -> 'a list) ->
    render:('a -> Html.node) ->
    Html.node

  (** Iterate with index *)
  val eachi :
    items:(unit -> 'a list) ->
    render:(int -> 'a -> Html.node) ->
    Html.node
end
```

### 5. Suspense / Error Boundaries

For async components and error handling:

```ocaml
module Tpl : sig
  (** Show fallback while loading *)
  val suspense :
    fallback:(unit -> Html.node) ->
    render:(unit -> Html.node) ->
    Html.node

  (** Catch errors and show error UI *)
  val error_boundary :
    fallback:(exn -> Html.node) ->
    render:(unit -> Html.node) ->
    Html.node
end
```

## Implementation Strategy

### Phase 1: Expose Existing Browser Features

The browser backend (`lib/solid-ml-browser/reactive.ml`) already has:
- `Reactive.show`
- `Reactive.if_`
- `bind_input`, `bind_checkbox`
- `bind_attr`, `bind_class`

**The template compiler just needs syntax for these!**

### Phase 2: Template Compiler Extensions

File to modify: `lib/solid-ml-template-ppx/solid_ml_template_ppx.ml`

1. Add `Tpl.show_when`, `Tpl.if_` to `known_tpl_markers`
2. Add attribute handlers for `Tpl.bind_input`, etc.
3. Add reactive attribute value support (detect thunks in attribute position)

### Phase 3: Template Runtime Extensions

File to modify: `lib/solid-ml-template-runtime/template_intf.ml`

Add slot types for:
- Conditional slots (show/hide regions)
- Binding slots (input/checkbox/select)
- Reactive attributes

## Priority Order

1. **HIGH**: `Tpl.show_when` / `Tpl.if_` - Required for conditional rendering
2. **HIGH**: `Tpl.bind_input`, `Tpl.bind_checkbox` - Required for forms
3. **MEDIUM**: Reactive attribute values - Required for dynamic classes/attrs
4. **MEDIUM**: `Tpl.each` (index-based) - Performance optimization
5. **LOW**: Suspense/Error boundaries - Nice to have

## Workarounds (Until Features Are Added)

Current workarounds are painful:

1. **Conditional rendering**: Render all branches, use CSS to hide
   ```ocaml
   (* Inefficient - renders both branches *)
   <div style_=("display:" ^ (if Signal.get show then "block" else "none"))>
     content_a
   </div>
   <div style_=("display:" ^ (if Signal.get show then "none" else "block"))>
     content_b
   </div>
   ```

2. **Form inputs**: Manual DOM manipulation in client.ml
   ```ocaml
   (* Can't use template compiler - have to write vanilla JS *)
   let input = Dom.create_element "input" in
   Dom.add_event_listener input "input" (fun ev ->
     let value = Dom.element_value ev in
     set_name value
   );
   ```

3. **Dynamic classes**: String concatenation (not reactive)
   ```ocaml
   (* Only evaluates once *)
   <div class_=("base " ^ (if condition then "active" else ""))>
   ```

## Impact

Without these features, solid-ml templates are:
- ❌ Not competitive with SolidJS expressiveness
- ❌ Require manual DOM manipulation for common patterns
- ❌ Force inefficient rendering (render all, hide some with CSS)
- ❌ Make SSR/hydration patterns difficult

With these features, solid-ml would:
- ✅ Match SolidJS feature parity
- ✅ Enable clean, declarative templates
- ✅ Support efficient reactivity
- ✅ Make SSR/hydration straightforward

## References

- SolidJS reactive control flow: https://www.solidjs.com/docs/latest/api#component-apis
- Browser reactive primitives: `lib/solid-ml-browser/reactive.mli`
- Template compiler: `lib/solid-ml-template-ppx/solid_ml_template_ppx.ml`
- Working examples: `examples/full_ssr_app/shared/components.mlx` (counter, todo list)

## Labels

`enhancement` `template-compiler` `reactivity` `feature-request` `good-first-issue`

---

**Note:** This issue was created while implementing multi-step forms, theme switcher, and async data fetching examples for `examples/full_ssr_app`. The work is currently blocked on these template compiler features.
