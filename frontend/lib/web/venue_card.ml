(** Venue card component for listing pages.
    Matches the website's venue list item styling with retro tags. *)

module H = Solid_ml_ssr.Html

(** Business status tag - for venue open/closed status *)
let business_status_tag ~(tr : I18n.translations) status =
  match status with
  | Api_types.In_business -> H.fragment []  (* Don't show tag for in_business *)
  | Api_types.Temporarily_closed ->
    H.div ~class_:"mb-2" ~children:[
      H.span ~class_:"retro-tag px-4 py-1.5 bg-orange-100 text-orange-700 dark:bg-orange-500/20 dark:text-orange-300 dark:border-orange-500 text-sm cursor-default"
        ~children:[H.text ("\226\143\184 " ^ tr.status_temp_closed)] ()
    ] ()
  | Api_types.Permanently_closed ->
    H.div ~class_:"mb-2" ~children:[
      H.span ~class_:"retro-tag px-4 py-1.5 bg-red-100 text-red-700 dark:bg-red-500/20 dark:text-red-300 dark:border-red-500 text-sm cursor-default"
        ~children:[H.text ("\226\156\149 " ^ tr.status_permanently_closed)] ()
    ] ()

(** Karaoke status tag - derived from events *)
let karaoke_status_tag ~(tr : I18n.translations) status =
  match status with
  | Api_types.Active_karaoke ->
    H.span ~class_:"retro-tag px-4 py-1.5 bg-success-100 text-success-700 dark:bg-green-500/20 dark:text-green-300 dark:border-green-500 text-sm cursor-default"
      ~children:[H.text ("\226\156\147 " ^ tr.status_active_karaoke)] ()
  | Api_types.Suspected_karaoke ->
    H.span ~class_:"retro-tag px-4 py-1.5 bg-yellow-100 text-yellow-700 dark:bg-yellow-500/20 dark:text-yellow-300 dark:border-yellow-500 text-sm cursor-default"
      ~children:[H.text ("? " ^ tr.status_suspected_karaoke)] ()
  | Api_types.No_karaoke ->
    H.span ~class_:"retro-tag px-4 py-1.5 bg-gray-100 text-gray-700 dark:bg-gray-500/20 dark:text-gray-300 dark:border-gray-500 text-sm cursor-default"
      ~children:[H.text ("\226\156\149 " ^ tr.status_no_karaoke)] ()

(** Venue type tag with icon *)
let venue_type_tag ~(tr : I18n.translations) venue_type =
  match venue_type with
  | Api_types.Public_stage ->
    H.span ~class_:"retro-tag px-4 py-1.5 bg-primary-100 text-primary-700 dark:bg-orange-500/20 dark:text-orange-300 dark:border-orange-500 text-sm cursor-pointer inline-flex items-center gap-1.5"
      ~children:[
        Components.icon ~class_:"w-3.5 h-3.5" "mic-2";
        H.text tr.type_public_stage
      ] ()
  | Api_types.Private_rooms ->
    H.span ~class_:"retro-tag px-4 py-1.5 bg-secondary-100 text-secondary-700 dark:bg-secondary-500/20 dark:text-secondary-300 dark:border-secondary-500 text-sm cursor-pointer inline-flex items-center gap-1.5"
      ~children:[
        Components.icon ~class_:"w-3.5 h-3.5" "door-closed";
        H.text tr.type_private_rooms
      ] ()
  | Api_types.Both ->
    H.span ~class_:"retro-tag px-4 py-1.5 bg-purple-100 text-purple-700 dark:bg-purple-500/20 dark:text-purple-300 dark:border-purple-500 text-sm cursor-pointer inline-flex items-center gap-1.5"
      ~children:[
        Components.icon ~class_:"w-3.5 h-3.5" "sparkles";
        H.text tr.type_both
      ] ()

(** Schedule dot indicator for a single day *)
let schedule_day ~(_tr : I18n.translations) ~active ~abbrev ~full_name =
  let sr_text = full_name ^ ": " ^ (if active then "Karaoke available" else "No karaoke") in
  let day_class = if active
    then "schedule-day schedule-day-active schedule-day-highlight"
    else "schedule-day schedule-day-inactive"
  in
  H.div ~class_:day_class ~children:[
    H.span ~class_:"schedule-day-label" ~children:[H.text abbrev] ();
    H.span ~class_:"schedule-dot" ~children:[] ();
    H.span ~class_:"sr-only" ~children:[H.text sr_text] ()
  ] ()

(** Day schedule display as dot indicators *)
let day_tags ~(tr : I18n.translations) karaoke_days =
  let all_days = [
    (tr.day_mon, tr.monday, "Monday");
    (tr.day_tue, tr.tuesday, "Tuesday");
    (tr.day_wed, tr.wednesday, "Wednesday");
    (tr.day_thu, tr.thursday, "Thursday");
    (tr.day_fri, tr.friday, "Friday");
    (tr.day_sat, tr.saturday, "Saturday");
    (tr.day_sun, tr.sunday, "Sunday");
  ] in
  let is_daily = List.mem "Daily" karaoke_days in
  let day_active internal_name =
    is_daily || List.mem internal_name karaoke_days
  in
  let translated_days = List.map (fun d ->
    match d with
    | "Daily" -> tr.day_daily
    | "Monday" -> tr.monday
    | "Tuesday" -> tr.tuesday
    | "Wednesday" -> tr.wednesday
    | "Thursday" -> tr.thursday
    | "Friday" -> tr.friday
    | "Saturday" -> tr.saturday
    | "Sunday" -> tr.sunday
    | "Irregular" -> tr.day_irregular
    | other -> other
  ) karaoke_days in
  let aria_label = Components.html_escape (tr.schedule ^ ": " ^ String.concat ", " translated_days) in
  H.div ~class_:"schedule" ~children:[
    H.raw (Printf.sprintf {|<div role="group" aria-label="%s" class="flex gap-0.5">|} aria_label);
    H.fragment (List.map (fun (abbrev, full_name, internal_name) ->
      schedule_day ~_tr:tr ~active:(day_active internal_name) ~abbrev ~full_name
    ) all_days);
    H.raw {|</div>|}
  ] ()

(** Venue list item class based on venue type *)
let list_item_class venue_type =
  match venue_type with
  | Api_types.Private_rooms -> "venue-list-item-alt"
  | Api_types.Both -> "venue-list-item venue-list-item-both"
  | Api_types.Public_stage -> "venue-list-item"

(** Render venue card from API list item *)
let render ~lang ~(tr : I18n.translations) (venue : Api_types.venue_list_item) =
  let base_class = list_item_class venue.venue_type in
  let card_class = base_class ^ " bg-white dark:bg-surface-800 rounded-xl p-6 block transition-all cursor-pointer" in
  H.a ~class_:card_class ~href:(I18n.url lang ("/venues/" ^ venue.slug)) ~children:[
    (* Business status tag (shown only for closed venues) *)
    business_status_tag ~tr venue.business_status;

    (* Venue name *)
    H.div ~class_:"text-xl font-bold text-gray-900 dark:text-white mb-2"
      ~children:[H.text venue.name] ();

    (* Location: City, Country *)
    H.div ~class_:"text-sm text-gray-600 dark:text-gray-400 mb-3" ~children:[
      H.text (venue.address_city ^ ", " ^ venue.address_country)
    ] ();

    (* Status tags row: karaoke status + venue type *)
    H.div ~class_:"flex items-center gap-3 mb-3 text-sm" ~children:[
      (* Only show karaoke status if venue is not permanently closed *)
      (if venue.business_status <> Api_types.Permanently_closed
       then karaoke_status_tag ~tr venue.karaoke_status
       else H.fragment []);
      (if venue.business_status <> Api_types.Permanently_closed
       then H.span ~class_:"text-gray-400 dark:text-gray-600" ~children:[H.text "\226\128\162"] ()
       else H.fragment []);
      venue_type_tag ~tr venue.venue_type
    ] ();

    (* Day schedule dots *)
    day_tags ~tr venue.karaoke_days
  ] ()

(** Render venue card from API detail (has all fields including karaoke_days) *)
let render_from_detail ~lang ~(tr : I18n.translations) (venue : Api_types.venue_detail) =
  let base_class = list_item_class venue.venue_type in
  let card_class = base_class ^ " bg-white dark:bg-surface-800 rounded-xl p-6 block transition-all cursor-pointer" in
  H.a ~class_:card_class ~href:(I18n.url lang ("/venues/" ^ venue.slug)) ~children:[
    (* Business status tag (shown only for closed venues) *)
    business_status_tag ~tr venue.business_status;

    (* Venue name *)
    H.div ~class_:"text-xl font-bold text-gray-900 dark:text-white mb-2"
      ~children:[H.text venue.name] ();

    (* Location: City, Country *)
    H.div ~class_:"text-sm text-gray-600 dark:text-gray-400 mb-3" ~children:[
      H.text (venue.address_city ^ ", " ^ venue.address_country)
    ] ();

    (* Status tags row: karaoke status + venue type *)
    H.div ~class_:"flex items-center gap-3 mb-3 text-sm" ~children:[
      (* Only show karaoke status if venue is not permanently closed *)
      (if venue.business_status <> Api_types.Permanently_closed
       then karaoke_status_tag ~tr venue.karaoke_status
       else H.fragment []);
      (if venue.business_status <> Api_types.Permanently_closed
       then H.span ~class_:"text-gray-400 dark:text-gray-600" ~children:[H.text "\226\128\162"] ()
       else H.fragment []);
      venue_type_tag ~tr venue.venue_type
    ] ();

    (* Day schedule dots *)
    day_tags ~tr venue.karaoke_days
  ] ()
