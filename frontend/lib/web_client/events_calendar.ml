(** Events calendar implementation - OCaml/Melange port of events-calendar.js

    Provides calendar view for karaoke events with:
    - Responsive design: week strip on mobile, full month grid on desktop
    - Date selection with event detail panel
    - View toggle between list and calendar
    - Status-based event indicators

    Uses solid-ml-browser reactive primitives for UI state management.
*)

(* ============================================================
   SOLID-ML REACTIVE PRIMITIVES
   ============================================================ *)

module Reactive = Solid_ml_browser.Reactive
module Dom = Solid_ml_browser.Dom

(* Ensure reactive runtime exists before creating signals at module level *)
let () = Reactive_init.ensure ()

(* View type for list/calendar toggle *)
type view = ListView | CalendarView

(* Reactive view state - the single source of truth for which view is active *)
let current_view_signal, set_current_view = Reactive.Signal.create ListView

(* Reactive signals for calendar state - triggers effects when changed *)
let selected_date_signal, set_selected_date_signal = Reactive.Signal.create (None : string option)
let calendar_month_signal, set_calendar_month_signal = Reactive.Signal.create (0, 0) (* year, month *)

(* Helper to check current view *)
let is_calendar_view () =
  match Reactive.Signal.get current_view_signal with
  | CalendarView -> true
  | ListView -> false

(* ============================================================
   DOM BINDINGS - Aliases from shared Map_dom module
   ============================================================ *)

(* Re-export types from Map_dom *)
type element = Map_dom.element
type event = Map_dom.event
type class_list = Map_dom.class_list

(* Re-export DOM functions from Map_dom *)
let document = Map_dom.document
let get_element_by_id = Map_dom.get_element_by_id
let query_selector_all = Map_dom.query_selector_all
let query_selector = Map_dom.query_selector
let get_attribute = Map_dom.get_attribute
let set_attribute = Map_dom.set_attribute
let get_text_content = Map_dom.get_text_content
let set_text_content = Map_dom.set_text_content
let get_inner_html = Map_dom.get_inner_html
let set_inner_html = Map_dom.set_inner_html
let add_event_listener = Map_dom.add_event_listener
let element_class_list = Map_dom.element_class_list
let class_list_add = Map_dom.class_list_add
let class_list_remove = Map_dom.class_list_remove
let class_list_contains = Map_dom.class_list_contains

(* Window bindings - re-export from Map_dom *)
type window = Map_dom.window
let window = Map_dom.window
let inner_width = Map_dom.inner_width
let add_resize_listener = Map_dom.add_window_event_listener

(* LocalStorage - re-export from Map_dom *)
let local_storage_get_item = Map_dom.local_storage_get_item
let local_storage_set_item = Map_dom.local_storage_set_item

(* Timer utilities - re-export from Map_dom *)
type timeout_id = Map_dom.timeout_id
let set_timeout = Map_dom.set_timeout
let clear_timeout = Map_dom.clear_timeout

(* ============================================================
   DATE UTILITIES (JavaScript interop)
   ============================================================ *)

let get_current_year : unit -> int = [%mel.raw {| function() { return new Date().getFullYear(); } |}]
let get_current_month : unit -> int = [%mel.raw {| function() { return new Date().getMonth(); } |}]
let get_current_date : unit -> int = [%mel.raw {| function() { return new Date().getDate(); } |}]

let get_days_in_month : int -> int -> int = [%mel.raw {|
  function(year, month) { return new Date(year, month + 1, 0).getDate(); }
|}]

let get_first_day_of_month : int -> int -> int = [%mel.raw {|
  function(year, month) { return new Date(year, month, 1).getDay(); }
|}]

let get_day_of_week_for_date : int -> int -> int -> int = [%mel.raw {|
  function(year, month, day) { return new Date(year, month, day).getDay(); }
|}]

(* ============================================================
   TYPES
   ============================================================ *)

type calendar_config = {
  weekdays_short : string array;
  weekdays_full : string array;
  months : string array;
  today_label : string;
  week_of_month_label : string;
  more_events_label : string;
  no_events_on_date : string;
  event_singular : string;
  event_plural : string;
  select_date_prompt : string;
  confirmed_label : string;
  expected_label : string;
  unverified_label : string;
  cancelled_label : string;
}

type event_item = {
  element : element;
  lat : float option;
  lng : float option;
  verification : string;
  month : string;
  isFirstOfMonth : bool; [@mel.as "isFirstOfMonth"]
  date : string;
}

type venue_info = {
  name : string;
  status : string;
}

type date_event_info = {
  total : int;
  confirmed : int;
  expected : int;
  suspected : int;
  cancelled : int;
  venues : venue_info list;
}

type calendar_state = {
  mutable current_year : int;
  mutable current_month : int;
  mutable current_week_start : int * int * int; (* year, month, day *)
  mutable selected_date : string option;
}

(* ============================================================
   MODULE STATE
   ============================================================ *)

let config : calendar_config option ref = ref None
let state : calendar_state ref = ref {
  current_year = 0;
  current_month = 0;
  current_week_start = (0, 0, 0);
  selected_date = None;
}
let filtered_items : event_item list ref = ref []
let was_mobile : bool ref = ref false

(* View preference storage key *)
let view_pref_key = "karaoke-events-view"

(* ============================================================
   STATUS UTILITIES
   ============================================================ *)

let status_priority = function
  | "confirmed" -> 0
  | "expected" -> 1
  | "suspected" -> 2
  | "cancelled" -> 3
  | _ -> 999

let get_status_color = function
  | "confirmed" -> "bg-success-500"
  | "expected" -> "bg-secondary-500"
  | "suspected" -> "bg-yellow-500"
  | "cancelled" -> "bg-red-500"
  | _ -> "bg-gray-500"

(* ============================================================
   VIEW PREFERENCE
   ============================================================ *)

let get_view_preference () =
  match Js.Nullable.toOption (local_storage_get_item view_pref_key) with
  | Some "calendar" -> "calendar"
  | _ -> "list"

let set_view_preference view =
  local_storage_set_item view_pref_key view

(* ============================================================
   DATE CALCULATIONS
   ============================================================ *)

let format_date_str year month day =
  Printf.sprintf "%04d-%02d-%02d" year (month + 1) day

let get_today_string () =
  format_date_str (get_current_year ()) (get_current_month ()) (get_current_date ())

(* Get the Monday of the week containing the given date *)
let get_week_start year month day =
  let dow = get_day_of_week_for_date year month day in
  (* Adjust so Monday = 0, Sunday = 6 *)
  let diff = if dow = 0 then -6 else 1 - dow in
  (* Simple date arithmetic - handles month boundaries via JS *)
  let adjust_date : int -> int -> int -> int -> int * int * int = [%mel.raw {|
    function(year, month, day, diff) {
      const d = new Date(year, month, day + diff);
      return [d.getFullYear(), d.getMonth(), d.getDate()];
    }
  |}] in
  adjust_date year month day diff

let add_days_to_date : int -> int -> int -> int -> int * int * int = [%mel.raw {|
  function(year, month, day, days) {
    const d = new Date(year, month, day + days);
    return [d.getFullYear(), d.getMonth(), d.getDate()];
  }
|}]

(* Get week number within month *)
let get_week_of_month year month day =
  let first_day = 1 in
  let (fy, fm, fd) = get_week_start year month first_day in
  let last_day = get_days_in_month year month in
  let (ly, lm, ld) = get_week_start year month last_day in

  (* Calculate total weeks using JS Date arithmetic *)
  let weeks_between : int -> int -> int -> int -> int -> int -> int = [%mel.raw {|
    function(y1, m1, d1, y2, m2, d2) {
      const d1ms = new Date(y1, m1, d1).getTime();
      const d2ms = new Date(y2, m2, d2).getTime();
      return Math.ceil((d2ms - d1ms) / (7 * 24 * 60 * 60 * 1000)) + 1;
    }
  |}] in
  let total_weeks = weeks_between fy fm fd ly lm ld in

  let (cy, cm, cd) = get_week_start year month day in
  let current_week = weeks_between fy fm fd cy cm cd in

  (max 1 (min current_week total_weeks), total_weeks)

(* ============================================================
   EVENT DATA PROCESSING
   ============================================================ *)

let get_event_counts_by_date () =
  let counts = Hashtbl.create 64 in
  List.iter (fun item ->
    let date_str = item.date in
    if date_str <> "" then begin
      let existing =
        try Hashtbl.find counts date_str
        with Not_found -> { total = 0; confirmed = 0; expected = 0; suspected = 0; cancelled = 0; venues = [] }
      in
      let updated = {
        total = existing.total + 1;
        confirmed = existing.confirmed + (if item.verification = "confirmed" then 1 else 0);
        expected = existing.expected + (if item.verification = "expected" then 1 else 0);
        suspected = existing.suspected + (if item.verification = "suspected" then 1 else 0);
        cancelled = existing.cancelled + (if item.verification = "cancelled" then 1 else 0);
        venues =
          (* Extract venue name from element *)
          let venue_name =
            match Js.Nullable.toOption (query_selector item.element "span.font-medium.text-primary-600") with
            | Some el ->
              (match Js.Nullable.toOption (get_text_content el) with
               | Some s -> String.trim s
               | None -> "")
            | None -> ""
          in
          if venue_name <> "" && not (List.exists (fun v -> v.name = venue_name) existing.venues) then
            { name = venue_name; status = item.verification } :: existing.venues
          else
            existing.venues
      } in
      Hashtbl.replace counts date_str updated
    end
  ) !filtered_items;

  (* Sort venues by priority within each date *)
  Hashtbl.iter (fun date_str info ->
    let sorted_venues = List.sort (fun a b ->
      compare (status_priority a.status) (status_priority b.status)
    ) info.venues in
    Hashtbl.replace counts date_str { info with venues = sorted_venues }
  ) counts;

  counts

(* ============================================================
   HTML ESCAPING
   ============================================================ *)

let escape_html : string -> string = [%mel.raw {|
  function(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
|}]

(* ============================================================
   MOBILE DETECTION
   ============================================================ *)

let is_mobile_view () =
  inner_width window < 768

(* ============================================================
   LIST UTILITIES
   ============================================================ *)

let rec take n lst = match n, lst with
  | 0, _ | _, [] -> []
  | n, x :: xs -> x :: take (n - 1) xs

(* ============================================================
   RENDERING UTILITIES
   ============================================================ *)

(* Format the "+X more" label using the config template *)
let format_more_label count =
  match !config with
  | Some cfg ->
    (* Replace %d with the count *)
    let replace_first : string -> string -> string -> string = [%mel.raw {|
      function(str, search, replace) { return str.replace(search, replace); }
    |}] in
    replace_first cfg.more_events_label "%d" (string_of_int count)
  | None -> Printf.sprintf "+%d" count

let generate_mobile_event_indicator info is_selected =
  if info.total = 0 then ""
  else
    let dot_base = "inline-block w-1.5 h-1.5 rounded-full" in
    let venues_to_show = take 3 info.venues in
    let dots = String.concat "" (List.map (fun venue ->
      Printf.sprintf {|<span class="%s %s"></span>|} dot_base (get_status_color venue.status)
    ) venues_to_show) in
    let more =
      if info.total > 3 then
        let text_color = if is_selected then "text-white" else "text-primary-600 dark:text-primary-400" in
        Printf.sprintf {|<span class="text-[9px] %s font-bold ml-0.5">%s</span>|} text_color (format_more_label (info.total - 3))
      else ""
    in
    Printf.sprintf {|<div class="flex gap-1 mt-1">%s%s</div>|} dots more

let generate_venue_preview info is_selected =
  if List.length info.venues = 0 then ""
  else
    let text_color = if is_selected then "text-primary-100" else "text-gray-500 dark:text-gray-400" in
    let more_color = if is_selected then "text-primary-200" else "text-gray-400 dark:text-gray-500" in
    let venues_to_show = take 2 info.venues in
    let venue_lines = String.concat "" (List.map (fun venue ->
      let dot_color = get_status_color venue.status in
      Printf.sprintf {|<p class="text-[9px] %s truncate leading-tight flex items-center gap-1"><span class="inline-block w-1.5 h-1.5 rounded-full %s flex-shrink-0"></span><span>%s</span></p>|}
        text_color dot_color (escape_html venue.name)
    ) venues_to_show) in
    let more_count = info.total - List.length venues_to_show in
    let more_line =
      if more_count > 0 then
        Printf.sprintf {|<p class="text-[8px] %s font-medium">%s</p>|} more_color (format_more_label more_count)
      else ""
    in
    Printf.sprintf {|<div class="mt-1 space-y-0.5 overflow-hidden">%s%s</div>|} venue_lines more_line

(* ============================================================
   CALENDAR RENDERING
   ============================================================ *)

let rec render_week_strip () =
  match !config with
  | None -> ()
  | Some cfg ->
    match Js.Nullable.toOption (get_element_by_id document "calendarWeekStrip") with
    | None -> ()
    | Some strip_el ->
      let st = !state in
      let (wy, wm, wd) = st.current_week_start in
      let event_counts = get_event_counts_by_date () in
      let today_str = get_today_string () in

      let html = Buffer.create 1024 in
      Buffer.add_string html {|<div class="grid grid-cols-7 gap-0.5">|};

      for i = 0 to 6 do
        let (dy, dm, dd) = add_days_to_date wy wm wd i in
        let date_str = format_date_str dy dm dd in
        let day_of_week = cfg.weekdays_short.(i) in
        let counts = try Some (Hashtbl.find event_counts date_str) with Not_found -> None in
        let is_selected = st.selected_date = Some date_str in
        let is_today = date_str = today_str in
        let has_events = match counts with Some c -> c.total > 0 | None -> false in

        let button_classes, style_attr, day_label_classes, day_num_classes, event_indicator =
          if is_selected then
            ("flex flex-col items-center py-3 rounded-lg border-2 border-black dark:border-primary-400 bg-primary-600",
             {| style="box-shadow: 2px 2px 0 rgba(0,0,0,0.5);"|},
             "text-[10px] uppercase text-primary-200",
             "text-lg font-bold mt-0.5 text-white",
             match counts with Some c -> generate_mobile_event_indicator c true | None -> "")
          else if is_today then
            ("flex flex-col items-center py-3 rounded-lg border-2 border-primary-500 bg-primary-50 dark:bg-primary-900/20",
             "",
             "text-[10px] uppercase text-primary-600 dark:text-primary-400",
             "text-lg font-bold mt-0.5 text-primary-600 dark:text-primary-400",
             match counts with Some c -> generate_mobile_event_indicator c false | None -> "")
          else if has_events then
            ("flex flex-col items-center py-3 rounded-lg border border-gray-200 dark:border-gray-700 bg-primary-50 dark:bg-primary-900/20 hover:border-primary-400",
             "",
             "text-[10px] uppercase text-gray-500",
             "text-lg font-bold mt-0.5 text-gray-900 dark:text-white",
             match counts with Some c -> generate_mobile_event_indicator c false | None -> "")
          else
            ("flex flex-col items-center py-3 rounded-lg border border-gray-200 dark:border-gray-700 hover:border-primary-400",
             "",
             "text-[10px] uppercase text-gray-400",
             "text-lg font-bold mt-0.5 text-gray-400",
             "")
        in

        Buffer.add_string html (Printf.sprintf
          {|<button class="%s"%s data-date="%s"><span class="%s">%s</span><span class="%s">%d</span>%s</button>|}
          button_classes style_attr date_str day_label_classes (escape_html day_of_week) day_num_classes dd event_indicator)
      done;

      Buffer.add_string html {|</div>|};
      set_inner_html strip_el (Buffer.contents html);

      (* Add click handlers *)
      let buttons = query_selector_all strip_el "[data-date]" in
      Array.iter (fun btn ->
        add_event_listener btn "click" (fun _ ->
          match Js.Nullable.toOption (get_attribute btn "data-date") with
          | Some date -> select_date date
          | None -> ()
        )
      ) buttons;

      update_week_indicator ()

and update_week_indicator () =
  match !config with
  | None -> ()
  | Some cfg ->
    match Js.Nullable.toOption (get_element_by_id document "calendarWeekIndicator") with
    | None -> ()
    | Some indicator_el ->
      let st = !state in
      let (wy, wm, wd) = st.current_week_start in
      (* Use middle of week to determine month context *)
      let (my, mm, md) = add_days_to_date wy wm wd 3 in
      let (week, total_weeks) = get_week_of_month my mm md in
      (* Replace %d placeholders - the label has format "Week %d of %d" *)
      let replace_first : string -> string -> string -> string = [%mel.raw {|
        function(str, search, replace) { return str.replace(search, replace); }
      |}] in
      let label =
        let s1 = replace_first cfg.week_of_month_label "%d" (string_of_int week) in
        replace_first s1 "%d" (string_of_int total_weeks)
      in
      set_text_content indicator_el label

and render_month_grid () =
  match !config with
  | None -> ()
  | Some cfg ->
    match Js.Nullable.toOption (get_element_by_id document "calendarDays") with
    | None -> ()
    | Some days_el ->
      let st = !state in
      let event_counts = get_event_counts_by_date () in
      let today_str = get_today_string () in

      (* Get first day of month (0 = Sunday) - convert to Monday-first (0 = Monday) *)
      let first_dow = get_first_day_of_month st.current_year st.current_month in
      let start_day_of_week = if first_dow = 0 then 6 else first_dow - 1 in
      let days_in_month = get_days_in_month st.current_year st.current_month in

      let html = Buffer.create 2048 in

      (* Empty cells before first day *)
      for _ = 1 to start_day_of_week do
        Buffer.add_string html {|<div class="h-24 rounded-lg bg-gray-50 dark:bg-gray-800/30"></div>|}
      done;

      (* Day cells *)
      for day = 1 to days_in_month do
        let date_str = format_date_str st.current_year st.current_month day in
        let counts = try Some (Hashtbl.find event_counts date_str) with Not_found -> None in
        let is_selected = st.selected_date = Some date_str in
        let is_today = date_str = today_str in
        let has_events = match counts with Some c -> c.total > 0 | None -> false in

        let cell_classes, style_attr, day_num_classes, preview_html, today_badge =
          if is_selected then
            ("h-24 rounded-lg p-2 cursor-pointer border-2 border-black dark:border-primary-500 bg-primary-600 text-white",
             {| style="box-shadow: 3px 3px 0 rgba(0,0,0,0.5);"|},
             "text-sm font-bold",
             (match counts with Some c -> generate_venue_preview c true | None -> ""),
             "")
          else if is_today then
            ("h-24 rounded-lg p-2 cursor-pointer border-2 border-primary-500 bg-primary-50 dark:bg-primary-900/30",
             "",
             "text-sm font-bold text-primary-600",
             (match counts with Some c -> generate_venue_preview c false | None -> ""),
             Printf.sprintf {|<span class="text-[8px] font-bold bg-primary-600 text-white px-1 rounded">%s</span>|} (escape_html cfg.today_label))
          else if has_events then
            ("h-24 rounded-lg p-2 cursor-pointer border border-gray-200 dark:border-gray-700 bg-primary-50 dark:bg-primary-900/20 hover:border-primary-400",
             "",
             "text-sm font-bold text-gray-900 dark:text-white",
             (match counts with Some c -> generate_venue_preview c false | None -> ""),
             "")
          else
            ("h-24 rounded-lg p-2 cursor-pointer border border-gray-200 dark:border-gray-700 hover:border-primary-400",
             "",
             "text-sm font-medium text-gray-400",
             "",
             "")
        in

        Buffer.add_string html (Printf.sprintf
          {|<div class="%s"%s data-date="%s"><div class="flex justify-between items-start"><span class="%s">%d</span>%s</div>%s</div>|}
          cell_classes style_attr date_str day_num_classes day today_badge preview_html)
      done;

      set_inner_html days_el (Buffer.contents html);

      (* Add click handlers *)
      let cells = query_selector_all days_el "[data-date]" in
      Array.iter (fun cell ->
        add_event_listener cell "click" (fun _ ->
          match Js.Nullable.toOption (get_attribute cell "data-date") with
          | Some date -> select_date date
          | None -> ()
        )
      ) cells

and render_calendar () =
  match !config with
  | None -> ()
  | Some cfg ->
    match Js.Nullable.toOption (get_element_by_id document "calendarMonthYear") with
    | None -> ()
    | Some month_year_el ->
      let st = !state in
      let month_name = cfg.months.(st.current_month) in
      set_text_content month_year_el (Printf.sprintf "%s %d" month_name st.current_year);
      render_week_strip ();
      render_month_grid ()

and select_date date_str =
  let st = !state in
  st.selected_date <- Some date_str;
  (* Sync to reactive signal *)
  set_selected_date_signal (Some date_str);

  (* Parse date to update month if needed *)
  let parts = String.split_on_char '-' date_str in
  match parts with
  | [year_s; month_s; _] ->
    (try
      let year = int_of_string year_s in
      let month = int_of_string month_s - 1 in
      if year <> st.current_year || month <> st.current_month then begin
        st.current_year <- year;
        st.current_month <- month;
        (* Sync to reactive signal *)
        set_calendar_month_signal (year, month)
      end;

      (* Update week start if selected date is outside current week *)
      let (_, _, day) =
        match parts with
        | [_; _; d] -> (year, month, int_of_string d)
        | _ -> (year, month, 1)
      in
      let (sy, sm, sd) = get_week_start year month day in
      let (wy, wm, wd) = st.current_week_start in
      if sy <> wy || sm <> wm || sd <> wd then
        st.current_week_start <- (sy, sm, sd)
    with _ -> ());

    render_calendar ();
    render_day_events date_str
  | _ -> ()

and render_day_events date_str =
  match !config with
  | None -> ()
  | Some cfg ->
    match Js.Nullable.toOption (get_element_by_id document "calendarDayEvents") with
    | None -> ()
    | Some panel_el ->
      (* Parse date *)
      let parts = String.split_on_char '-' date_str in
      match parts with
      | [year_s; month_s; day_s] ->
        (try
          let year = int_of_string year_s in
          let month = int_of_string month_s - 1 in
          let day = int_of_string day_s in
          let dow = get_day_of_week_for_date year month day in
          let weekday_name = cfg.weekdays_full.(dow) in
          let month_name = cfg.months.(month) in

          (* Find matching events *)
          let matching_items = List.filter (fun item -> item.date = date_str) !filtered_items in
          let sorted_items = List.sort (fun a b ->
            compare (status_priority a.verification) (status_priority b.verification)
          ) matching_items in

          if List.length sorted_items = 0 then
            set_inner_html panel_el (Printf.sprintf
              {|<div class="text-center text-gray-500 dark:text-gray-400 py-6">
                <p class="font-medium text-gray-900 dark:text-white mb-2">%s, %s %d</p>
                <p>%s</p>
              </div>|}
              (escape_html weekday_name) (escape_html month_name) day (escape_html cfg.no_events_on_date))
          else begin
            let event_label = if List.length sorted_items = 1 then cfg.event_singular else cfg.event_plural in
            let html = Buffer.create 2048 in

            Buffer.add_string html (Printf.sprintf
              {|<div class="flex items-center justify-between mb-3">
                <h4 class="font-bold text-gray-900 dark:text-white">%s, %s %d</h4>
                <span class="text-sm font-bold text-primary-600 dark:text-primary-400">%d %s</span>
              </div>
              <div class="space-y-2">|}
              (escape_html weekday_name) (escape_html month_name) day
              (List.length sorted_items) (escape_html event_label));

            List.iter (fun item ->
              (* Extract event details from element *)
              let title =
                match Js.Nullable.toOption (query_selector item.element "h3") with
                | Some el -> (match Js.Nullable.toOption (get_text_content el) with Some s -> String.trim s | None -> "Event")
                | None -> "Event"
              in
              let venue =
                match Js.Nullable.toOption (query_selector item.element "span.font-medium.text-primary-600") with
                | Some el -> (match Js.Nullable.toOption (get_text_content el) with Some s -> String.trim s | None -> "")
                | None -> ""
              in
              let href =
                match Js.Nullable.toOption (query_selector item.element "a[href*=\"/event\"]") with
                | Some el -> (match Js.Nullable.toOption (get_attribute el "href") with Some s -> s | None -> "#")
                | None -> "#"
              in
              let indicator_color = get_status_color item.verification in

              Buffer.add_string html (Printf.sprintf
                {|<a href="%s" class="flex items-center gap-3 p-2.5 bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 hover:border-primary-400 transition-colors">
                  <div class="w-1.5 h-12 rounded-full %s"></div>
                  <div class="flex-1 min-w-0">
                    <p class="font-medium text-gray-900 dark:text-white truncate">%s</p>
                    <p class="text-sm text-gray-500 dark:text-gray-400">%s</p>
                  </div>
                  <svg class="w-5 h-5 text-gray-400 flex-shrink-0" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                  </svg>
                </a>|}
                (escape_html href) indicator_color (escape_html title) (escape_html venue))
            ) sorted_items;

            Buffer.add_string html {|</div>|};

            (* Add legend *)
            Buffer.add_string html (Printf.sprintf
              {|<div class="mt-3 pt-3 border-t border-gray-200 dark:border-gray-700 grid grid-cols-2 gap-2 text-xs text-gray-500 dark:text-gray-400">
                <div class="flex items-center gap-1.5">
                  <span class="w-2 h-4 rounded-full bg-success-500"></span>
                  <span>%s</span>
                </div>
                <div class="flex items-center gap-1.5">
                  <span class="w-2 h-4 rounded-full bg-secondary-500"></span>
                  <span>%s</span>
                </div>
                <div class="flex items-center gap-1.5">
                  <span class="w-2 h-4 rounded-full bg-yellow-500"></span>
                  <span>%s</span>
                </div>
                <div class="flex items-center gap-1.5">
                  <span class="w-2 h-4 rounded-full bg-red-500"></span>
                  <span>%s</span>
                </div>
              </div>|}
              (escape_html cfg.confirmed_label)
              (escape_html cfg.expected_label)
              (escape_html cfg.unverified_label)
              (escape_html cfg.cancelled_label));

            set_inner_html panel_el (Buffer.contents html)
          end
        with _ -> ())
      | _ -> ()

let reset_day_events_panel () =
  match !config with
  | None -> ()
  | Some cfg ->
    match Js.Nullable.toOption (get_element_by_id document "calendarDayEvents") with
    | None -> ()
    | Some panel_el ->
      set_inner_html panel_el (Printf.sprintf
        {|<div class="text-center text-gray-500 dark:text-gray-400 py-4">%s</div>|}
        (escape_html cfg.select_date_prompt))

(* ============================================================
   NAVIGATION
   ============================================================ *)

let prev_month () =
  let st = !state in
  if is_mobile_view () then begin
    (* Move back one week *)
    let (wy, wm, wd) = st.current_week_start in
    let (ny, nm, nd) = add_days_to_date wy wm wd (-7) in
    st.current_week_start <- (ny, nm, nd);
    (* Update month/year based on mid-week *)
    let (my, mm, _) = add_days_to_date ny nm nd 3 in
    st.current_month <- mm;
    st.current_year <- my
  end else begin
    (* Move back one month *)
    if st.current_month = 0 then begin
      st.current_month <- 11;
      st.current_year <- st.current_year - 1
    end else
      st.current_month <- st.current_month - 1;
    (* Update week start to first week of new month *)
    st.current_week_start <- get_week_start st.current_year st.current_month 1
  end;
  st.selected_date <- None;
  (* Sync to reactive signals *)
  set_selected_date_signal None;
  set_calendar_month_signal (st.current_year, st.current_month);
  render_calendar ();
  reset_day_events_panel ()

let next_month () =
  let st = !state in
  if is_mobile_view () then begin
    (* Move forward one week *)
    let (wy, wm, wd) = st.current_week_start in
    let (ny, nm, nd) = add_days_to_date wy wm wd 7 in
    st.current_week_start <- (ny, nm, nd);
    (* Update month/year based on mid-week *)
    let (my, mm, _) = add_days_to_date ny nm nd 3 in
    st.current_month <- mm;
    st.current_year <- my
  end else begin
    (* Move forward one month *)
    if st.current_month = 11 then begin
      st.current_month <- 0;
      st.current_year <- st.current_year + 1
    end else
      st.current_month <- st.current_month + 1;
    (* Update week start to first week of new month *)
    st.current_week_start <- get_week_start st.current_year st.current_month 1
  end;
  st.selected_date <- None;
  (* Sync to reactive signals *)
  set_selected_date_signal None;
  set_calendar_month_signal (st.current_year, st.current_month);
  render_calendar ();
  reset_day_events_panel ()

(* ============================================================
   VIEW TOGGLING - Uses reactive signal for state
   ============================================================ *)

(* Show list view - updates signal, reactive bindings handle DOM *)
let show_list_view () =
  set_view_preference "list";
  set_current_view ListView

(* Show calendar view - updates signal, reactive bindings handle DOM *)
let show_calendar_view () =
  set_view_preference "calendar";
  set_current_view CalendarView;
  render_calendar ()

(* Setup reactive bindings for view toggle - called once during init *)
let setup_view_bindings () =
  (* Create derived signals for visibility *)
  let is_list_view = Reactive.Memo.create (fun () ->
    match Reactive.Signal.get current_view_signal with
    | ListView -> true
    | CalendarView -> false
  ) in
  let is_calendar_view_memo = Reactive.Memo.create (fun () ->
    match Reactive.Signal.get current_view_signal with
    | CalendarView -> true
    | ListView -> false
  ) in

  (* Helper to convert memo to signal for bind functions *)
  let memo_to_signal memo =
    let sig_, _set_sig = Reactive.Signal.create (Reactive.Memo.get memo) in
    Reactive.Effect.create (fun () ->
      let v = Reactive.Memo.get memo in
      Reactive.Signal.set sig_ v
    );
    sig_
  in

  let list_visible_signal = memo_to_signal is_list_view in
  let calendar_visible_signal = memo_to_signal is_calendar_view_memo in

  (* Bind visibility to elements *)
  (match Dom.get_element_by_id Dom.document "eventList" with
   | Some el -> Reactive.bind_show el list_visible_signal
   | None -> ());
  (match Dom.get_element_by_id Dom.document "eventPagination" with
   | Some el -> Reactive.bind_show el list_visible_signal
   | None -> ());
  (match Dom.get_element_by_id Dom.document "calendarView" with
   | Some el -> Reactive.bind_show el calendar_visible_signal
   | None -> ());

  (* Bind button active states using class toggles *)
  (* List button: active when list view *)
  (match Dom.get_element_by_id Dom.document "listViewBtn" with
   | Some btn ->
     Reactive.bind_class_toggle btn "bg-primary-100" list_visible_signal;
     Reactive.bind_class_toggle btn "dark:bg-primary-900/30" list_visible_signal;
     Reactive.bind_class_toggle btn "text-primary-700" list_visible_signal;
     Reactive.bind_class_toggle btn "dark:text-primary-300" list_visible_signal;
     Reactive.bind_class_toggle btn "bg-white" calendar_visible_signal;
     Reactive.bind_class_toggle btn "dark:bg-gray-800" calendar_visible_signal;
     Reactive.bind_class_toggle btn "text-gray-600" calendar_visible_signal;
     Reactive.bind_class_toggle btn "dark:text-gray-400" calendar_visible_signal
   | None -> ());
  (* Calendar button: active when calendar view *)
  (match Dom.get_element_by_id Dom.document "calendarViewBtn" with
   | Some btn ->
     Reactive.bind_class_toggle btn "bg-primary-100" calendar_visible_signal;
     Reactive.bind_class_toggle btn "dark:bg-primary-900/30" calendar_visible_signal;
     Reactive.bind_class_toggle btn "text-primary-700" calendar_visible_signal;
     Reactive.bind_class_toggle btn "dark:text-primary-300" calendar_visible_signal;
     Reactive.bind_class_toggle btn "bg-white" list_visible_signal;
     Reactive.bind_class_toggle btn "dark:bg-gray-800" list_visible_signal;
     Reactive.bind_class_toggle btn "text-gray-600" list_visible_signal;
     Reactive.bind_class_toggle btn "dark:text-gray-400" list_visible_signal
   | None -> ())

(* ============================================================
   RESIZE HANDLING
   ============================================================ *)

(* Timer for debouncing resize events - uses setTimeout/clearTimeout from Map_dom *)
let resize_timer : timeout_id option ref = ref None

let handle_resize_impl () =
  let is_mobile = is_mobile_view () in
  if is_mobile <> !was_mobile then begin
    was_mobile := is_mobile;
    (* Re-render if calendar view is active *)
    if is_calendar_view () then render_calendar ()
  end

let handle_resize () =
  (* Debounce: cancel pending timer and schedule new one *)
  (match !resize_timer with
   | Some timer -> clear_timeout timer
   | None -> ());
  resize_timer := Some (set_timeout handle_resize_impl 150)

(* ============================================================
   PUBLIC API
   ============================================================ *)

let update_filtered_items (items : event_item list) =
  filtered_items := items;
  (* If calendar view is active, re-render it *)
  if is_calendar_view () then begin
    render_calendar ();
    match (!state).selected_date with
    | Some date -> render_day_events date
    | None -> ()
  end

let init_calendar cfg =
  config := Some cfg;

  (* Initialize state with current date context *)
  let year = get_current_year () in
  let month = get_current_month () in
  let day = get_current_date () in
  state := {
    current_year = year;
    current_month = month;
    current_week_start = get_week_start year month day;
    selected_date = None;
  };

  (* Initialize reactive signals to match state *)
  set_calendar_month_signal (year, month);
  set_selected_date_signal None;

  (* Track initial breakpoint *)
  was_mobile := is_mobile_view ();

  (* Set up reactive bindings for view toggle *)
  setup_view_bindings ();

  (* Set up view toggle buttons *)
  (match Js.Nullable.toOption (get_element_by_id document "listViewBtn") with
   | Some btn -> add_event_listener btn "click" (fun _ -> show_list_view ())
   | None -> ());
  (match Js.Nullable.toOption (get_element_by_id document "calendarViewBtn") with
   | Some btn -> add_event_listener btn "click" (fun _ -> show_calendar_view ())
   | None -> ());

  (* Set up navigation buttons *)
  (match Js.Nullable.toOption (get_element_by_id document "calendarPrevMonth") with
   | Some btn -> add_event_listener btn "click" (fun _ -> prev_month ())
   | None -> ());
  (match Js.Nullable.toOption (get_element_by_id document "calendarNextMonth") with
   | Some btn -> add_event_listener btn "click" (fun _ -> next_month ())
   | None -> ());

  (* Listen for resize to handle breakpoint changes *)
  add_resize_listener window "resize" handle_resize;

  (* Restore view preference - set signal to match preference *)
  if get_view_preference () = "calendar" then
    show_calendar_view ()
  else
    show_list_view ()

(* ============================================================
   WINDOW EXPORTS
   ============================================================ *)

(* Export API to window for events.js integration *)
let () =
  let api = [%mel.obj {
    initCalendar = init_calendar;
    updateFilteredItems = update_filtered_items;
  }] in
  Map_dom.set_window "EventsCalendar" api

(* Export dummy value for app.ml module inclusion *)
let calendar_initialized = true
