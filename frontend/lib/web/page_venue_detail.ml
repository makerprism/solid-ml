(** Venue detail page. *)

open Lwt.Syntax

module H = Solid_ml_ssr.Html

(* Use shared escape functions from Components *)
let json_escape = Components.json_escape
let html_escape = Components.html_escape
let js_escape = Components.js_escape
let icon = Components.icon

(** Generate JSON-LD structured data for a venue *)
let generate_structured_data ~lang ~(venue : Api_types.venue_detail) ~(tr : I18n.translations) =
  let base_url = "https://karaokecrowd.com" in
  let lang_prefix = "/" ^ I18n.lang_code lang in
  let venue_url = base_url ^ lang_prefix ^ "/venues/" ^ venue.slug in
  
  (* Build telephone JSON if available *)
  let telephone_json = match venue.phone with
    | Some phone when phone <> "" -> Printf.sprintf {|,
  "telephone": "%s"|} (json_escape phone)
    | _ -> ""
  in
  
  (* Build sameAs array for social links *)
  let social_urls = List.filter_map (fun x -> x) [
    Option.map (fun w -> "\"" ^ json_escape w ^ "\"") venue.website;
    Option.map (fun fb -> "\"https://facebook.com/" ^ json_escape fb ^ "\"") venue.facebook;
    Option.map (fun ig -> "\"https://instagram.com/" ^ json_escape ig ^ "\"") venue.instagram;
  ] in
  let same_as_json = if List.length social_urls > 0 then
    Printf.sprintf {|,
  "sameAs": [%s]|} (String.concat ", " social_urls)
  else ""
  in
  
  (* LocalBusiness JSON-LD *)
  let local_business = Printf.sprintf {|{
  "@context": "https://schema.org",
  "@type": "LocalBusiness",
  "name": "%s",
  "description": "%s",
  "url": "%s",
  "image": "%s/images/og-default.png",
  "address": {
    "@type": "PostalAddress",
    "streetAddress": "%s",
    "addressLocality": "%s",
    "postalCode": "%s",
    "addressRegion": "%s",
    "addressCountry": "%s"
  }%s%s%s
}|}
    (json_escape venue.name)
    (json_escape (I18n.format_s tr.karaoke_venue_in venue.address_city))
    venue_url
    base_url
    (json_escape venue.address_street)
    (json_escape venue.address_city)
    (json_escape venue.address_zip)
    (json_escape venue.address_state)
    (json_escape venue.address_country)
    (* Add geo coordinates if available *)
    (match venue.lat, venue.lng with
     | Some lat, Some lng -> Printf.sprintf {|,
  "geo": {
    "@type": "GeoCoordinates",
    "latitude": %f,
    "longitude": %f
  }|} lat lng
     | _ -> "")
    telephone_json
    same_as_json
  in
  
  (* BreadcrumbList JSON-LD *)
  let breadcrumb = Printf.sprintf {|{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    {
      "@type": "ListItem",
      "position": 1,
      "name": "%s",
      "item": "%s%s/"
    },
    {
      "@type": "ListItem",
      "position": 2,
      "name": "%s",
      "item": "%s%s/venues/"
    },
    {
      "@type": "ListItem",
      "position": 3,
      "name": "%s"
    }
  ]
}|}
    (json_escape tr.breadcrumb_home)
    base_url lang_prefix
    (json_escape tr.breadcrumb_venues)
    base_url lang_prefix
    (json_escape venue.name)
  in
  
  (* Combine both schemas *)
  Printf.sprintf "[%s, %s]" local_business breadcrumb

(* Render business status banner *)
let business_status_banner ~(tr : I18n.translations) (status : Api_types.business_status) =
  match status with
  | Api_types.In_business -> H.fragment []
  | Api_types.Temporarily_closed ->
    H.div ~class_:"bg-yellow-50 dark:bg-yellow-900/20 border-2 border-yellow-500 rounded-xl p-4 mb-6 flex items-center gap-3" ~children:[
      icon ~class_:"w-5 h-5 text-yellow-600 dark:text-yellow-400" "pause-circle";
      H.span ~class_:"font-bold text-yellow-700 dark:text-yellow-300 uppercase tracking-wide" ~children:[
        H.text tr.status_temp_closed
      ] ()
    ] ()
  | Api_types.Permanently_closed ->
    H.div ~class_:"bg-red-50 dark:bg-red-900/20 border-2 border-red-500 rounded-xl p-4 mb-6 flex items-center gap-3" ~children:[
      icon ~class_:"w-5 h-5 text-red-600 dark:text-red-400" "x-circle";
      H.span ~class_:"font-bold text-red-700 dark:text-red-300 uppercase tracking-wide" ~children:[
        H.text tr.status_permanently_closed
      ] ()
    ] ()

(* Venue type tag component *)
let venue_type_tag ~(tr : I18n.translations) (venue_type : Api_types.venue_type) =
  match venue_type with
  | Api_types.Private_rooms ->
    H.span ~class_:"retro-tag retro-tag-static px-4 py-1.5 bg-secondary-100 text-secondary-700 dark:bg-secondary-500/20 dark:text-secondary-300 dark:border-secondary-500 text-sm inline-flex items-center gap-1.5" ~children:[
      icon ~class_:"w-3.5 h-3.5" "door-closed";
      H.text tr.type_private_rooms
    ] ()
  | Api_types.Public_stage ->
    H.span ~class_:"retro-tag retro-tag-static px-4 py-1.5 bg-primary-100 text-primary-700 dark:bg-orange-500/20 dark:text-orange-300 dark:border-orange-500 text-sm inline-flex items-center gap-1.5" ~children:[
      icon ~class_:"w-3.5 h-3.5" "mic-2";
      H.text tr.type_public_stage
    ] ()
  | Api_types.Both ->
    H.span ~class_:"retro-tag retro-tag-static px-4 py-1.5 bg-purple-100 text-purple-700 dark:bg-purple-500/20 dark:text-purple-300 dark:border-purple-500 text-sm inline-flex items-center gap-1.5" ~children:[
      icon ~class_:"w-3.5 h-3.5" "mic-2";
      H.text tr.type_both
    ] ()

(* Business status tag component *)
let business_status_tag ~(tr : I18n.translations) (status : Api_types.business_status) =
  match status with
  | Api_types.In_business ->
    H.span ~class_:"retro-tag retro-tag-static px-4 py-1.5 bg-success-100 text-success-700 dark:bg-green-500/20 dark:text-green-300 dark:border-green-500 text-sm inline-flex items-center gap-1.5" ~children:[
      icon ~class_:"w-3.5 h-3.5" "check-circle";
      H.text tr.status_in_business
    ] ()
  | Api_types.Temporarily_closed ->
    H.span ~class_:"retro-tag retro-tag-static px-4 py-1.5 bg-yellow-100 text-yellow-700 dark:bg-yellow-500/20 dark:text-yellow-300 dark:border-yellow-500 text-sm inline-flex items-center gap-1.5" ~children:[
      icon ~class_:"w-3.5 h-3.5" "pause-circle";
      H.text tr.status_temp_closed
    ] ()
  | Api_types.Permanently_closed ->
    H.span ~class_:"retro-tag retro-tag-static px-4 py-1.5 bg-red-100 text-red-700 dark:bg-red-500/20 dark:text-red-300 dark:border-red-500 text-sm inline-flex items-center gap-1.5" ~children:[
      icon ~class_:"w-3.5 h-3.5" "x-circle";
      H.text tr.status_permanently_closed
    ] ()

(* Series status badge *)
let series_status_badge ~(tr : I18n.translations) (status : Api_types.series_status) =
  match status with
  | Api_types.Active ->
    H.span ~class_:"inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-success-100 text-success-700 dark:bg-green-500/20 dark:text-green-300 border border-success-300 dark:border-green-500/50" ~children:[
      icon ~class_:"w-3.5 h-3.5" "check-circle";
      H.text tr.series_status_active
    ] ()
   | Api_types.Suspected ->
    H.span ~class_:"inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-yellow-100 text-yellow-700 dark:bg-yellow-500/20 dark:text-yellow-300 border border-yellow-300 dark:border-yellow-500/50" ~children:[
      icon ~class_:"w-3.5 h-3.5" "help-circle";
      H.text tr.series_status_suspected
    ] ()
  | Api_types.Paused ->
    H.span ~class_:"inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-gray-100 text-gray-600 dark:bg-gray-500/20 dark:text-gray-400 border border-gray-300 dark:border-gray-500/50" ~children:[
      icon ~class_:"w-3.5 h-3.5" "pause-circle";
      H.text tr.series_status_paused
    ] ()
  | Api_types.Ended ->
    H.span ~class_:"inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-gray-100 text-gray-500 dark:bg-gray-500/20 dark:text-gray-500 border border-gray-300 dark:border-gray-500/50" ~children:[
      icon ~class_:"w-3.5 h-3.5" "x-circle";
      H.text tr.series_status_ended
    ] ()

let render_evidence ~lang ~(tr : I18n.translations) (evidence : Yojson.Basic.t) =
  match evidence with
  | `Assoc fields ->
    let report = List.assoc_opt "report" fields |> Option.map Yojson.Basic.Util.to_string in
    let url = match List.assoc_opt "url" fields with
      | Some (`String s) -> Some s | _ -> None
    in
    let date = List.assoc_opt "date" fields |> Option.map Yojson.Basic.Util.to_string in
    let _ = lang in
    H.div ~class_:"bg-gray-50 dark:bg-gray-800/50 rounded-lg p-4 border-2 border-gray-200 dark:border-gray-700" ~children:[
      (match report with 
       | Some r -> H.p ~class_:"text-sm text-gray-700 dark:text-gray-300 mb-2" ~children:[H.text r] () 
       | None -> H.fragment []);
      H.div ~class_:"flex items-center gap-3 text-xs text-gray-600 dark:text-gray-400 flex-wrap" ~children:[
        (match date with
         | Some d -> 
           H.span ~class_:"flex items-center gap-1" ~children:[
             icon ~class_:"w-3 h-3" "calendar";
             H.text d
           ] ()
         | None -> H.fragment []);
        (match url with
         | Some u -> 
           H.raw (Printf.sprintf 
             {|<a href="%s" target="_blank" rel="noopener noreferrer" class="text-primary-600 dark:text-primary-400 hover:underline flex items-center gap-1"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-3 h-3"><path d="M15 3h6v6"/><path d="M10 14 21 3"/><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/></svg>%s</a>|}
             (html_escape u) tr.links)
         | None -> H.fragment [])
      ] ()
    ] ()
  | _ -> H.fragment []

let render ~lang ~(tr : I18n.translations) ~(venue : Api_types.venue_detail) ~(event_series : Api_types.event_series_embedded list) () =
  let lang_code = I18n.lang_code lang in
  (* Generate Google Maps URLs *)
  let maps_query = 
    let query_str = Printf.sprintf "%s, %s, %s, %s" venue.name venue.address_street venue.address_city venue.address_country in
    Str.global_replace (Str.regexp " ") "+" query_str
  in
  let directions_url = "https://www.google.com/maps/dir/?api=1&destination=" ^ maps_query in
  let maps_url = "https://www.google.com/maps/search/?api=1&query=" ^ maps_query in
  
  let evidence = venue.karaoke_evidence in
  let evidence_list = match evidence with `List l -> l | _ -> [] in
  
  H.fragment [
    H.div ~class_:"max-w-4xl mx-auto" ~children:[
      (* Breadcrumb Navigation *)
      H.nav ~class_:"text-sm mb-6" ~children:[
        H.ol ~class_:"flex items-center gap-2 text-gray-700 dark:text-gray-400" ~children:[
          H.li ~children:[
            H.a ~href:(I18n.url lang "/") ~class_:"hover:text-primary-600 dark:hover:text-primary-400 transition-colors" ~children:[
              H.text tr.breadcrumb_home
            ] ()
          ] ();
          H.li ~children:[icon "chevron-right"] ();
          H.li ~children:[
            H.a ~href:(I18n.url lang "/venues") ~class_:"hover:text-primary-600 dark:hover:text-primary-400 transition-colors" ~children:[
              H.text tr.breadcrumb_venues
            ] ()
          ] ();
          H.li ~children:[icon "chevron-right"] ();
          H.li ~class_:"text-gray-900 dark:text-white font-semibold" ~children:[
            H.text venue.name
          ] ()
        ] ()
      ] ();
      
      (* Status banners *)
      business_status_banner ~tr venue.business_status;
      
      (* Page Title *)
      H.h1 ~class_:"text-4xl md:text-5xl font-bold font-heading text-gray-900 dark:text-white mb-6" ~children:[
        H.text venue.name
      ] ();
      
      (* Quick Actions Bar *)
      H.div ~class_:"flex flex-wrap gap-3 mb-6" ~children:[
        H.raw (Printf.sprintf 
          {|<a href="%s" target="_blank" rel="noopener noreferrer" class="px-5 py-3 rounded-lg text-base font-semibold transition-all bg-primary-600 hover:bg-primary-700 text-white retro-btn-primary inline-flex items-center gap-2"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-5 h-5"><polygon points="3 11 22 2 13 21 11 13 3 11"/></svg>%s</a>|}
          (html_escape directions_url) (html_escape tr.get_directions));
        (match venue.phone with
          | Some phone when phone <> "" ->
            H.a ~href:("tel:" ^ phone)
                ~class_:"px-5 py-3 rounded-lg text-base font-semibold transition-all bg-secondary-500 hover:bg-secondary-600 text-white retro-btn-accent inline-flex items-center gap-2" ~children:[
              icon "phone";
              H.text tr.call
            ] ()
         | _ -> H.fragment []);
        H.raw (Printf.sprintf {|<button onclick="navigator.share ? navigator.share({title: document.title, url: window.location.href}) : navigator.clipboard.writeText(window.location.href).then(() => alert('%s'))" class="px-5 py-3 rounded-lg text-base font-semibold transition-all bg-gray-200 hover:bg-gray-300 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-900 dark:text-white border-2 border-gray-700 dark:border-gray-500 inline-flex items-center gap-2"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-5 h-5"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><line x1="8.59" x2="15.42" y1="13.51" y2="17.49"/><line x1="15.41" x2="8.59" y1="6.51" y2="10.49"/></svg>%s</button>|} 
          (js_escape tr.link_copied) (html_escape tr.share));
        
        (* Follow venue button *)
        H.button ~id:"follow-btn" ~type_:"button"
          ~class_:"px-5 py-3 rounded-lg text-base font-semibold transition-all bg-pink-500 hover:bg-pink-600 text-white border-2 border-pink-700 inline-flex items-center gap-2"
          ~children:[
            icon ~class_:"w-5 h-5" "heart";
            H.span ~id:"follow-btn-text" ~children:[H.text tr.follow_venue] ()
          ] ();
        
        (* Suggest edit link *)
        H.a ~href:(I18n.url lang ("/venues/" ^ venue.slug ^ "/edit"))
            ~class_:"px-5 py-3 rounded-lg text-base font-semibold transition-all bg-gray-200 hover:bg-gray-300 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-900 dark:text-white border-2 border-gray-700 dark:border-gray-500 inline-flex items-center gap-2" ~children:[
          icon ~class_:"w-5 h-5" "pencil";
          H.text tr.suggest_edit
        ] ()
      ] ();
      
      (* Regulars count *)
      H.div ~id:"regulars-count-container" ~class_:"flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400 mb-6" ~children:[
        icon ~class_:"w-4 h-4" "users";
        H.span ~id:"regulars-count" ~children:[H.text "..."] ()
      ] ();
      
      (* Karaoke Info and Venue Details - Side by Side on Desktop *)
      H.div ~class_:"grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6" ~children:[
        (* Karaoke Info Card *)
        H.div ~class_:"retro-card bg-white dark:bg-surface-800 rounded-xl p-8" ~children:[
          H.h3 ~class_:"text-lg font-bold font-heading text-gray-900 dark:text-white mb-4" ~children:[
            H.text tr.karaoke_info
          ] ();
          H.div ~class_:"space-y-3" ~children:[
            (* Type *)
            H.div ~class_:"flex items-center gap-2" ~children:[
              H.span ~class_:"text-sm text-gray-700 dark:text-gray-400" ~children:[H.text tr.type_label] ();
              venue_type_tag ~tr venue.venue_type
            ] ();
            (* Status *)
            H.div ~class_:"flex items-center gap-2" ~children:[
              H.span ~class_:"text-sm text-gray-700 dark:text-gray-400" ~children:[H.text tr.status_label] ();
              business_status_tag ~tr venue.business_status
            ] ();
            (* Karaoke Days - Schedule dot indicator *)
            H.div ~class_:"pt-3 border-t-2 border-gray-200 dark:border-gray-700" ~children:[
              H.h4 ~class_:"text-sm font-semibold font-heading text-gray-700 dark:text-gray-400 mb-3" ~children:[
                H.text tr.schedule
              ] ();
              Venue_card.day_tags ~tr venue.karaoke_days
            ] ()
          ] ()
        ] ();
        
        (* Venue Details Card *)
        H.div ~class_:"retro-card bg-white dark:bg-surface-800 rounded-xl p-8" ~children:[
          H.h3 ~class_:"text-lg font-bold font-heading text-gray-900 dark:text-white mb-4" ~children:[
            H.text tr.venue_details
          ] ();
          H.div ~class_:"space-y-4" ~children:[
            (* Address *)
            H.div ~class_:"space-y-2" ~children:[
              H.div ~class_:"flex items-start gap-2" ~children:[
                H.div ~class_:"w-4 h-4 text-gray-600 dark:text-gray-400 mt-0.5 flex-shrink-0" ~children:[
                  icon "map-pin"
                ] ();
                H.raw (Printf.sprintf 
                  {|<a href="%s" target="_blank" rel="noopener noreferrer" class="text-gray-700 dark:text-gray-300 hover:text-primary-600 dark:hover:text-primary-400 hover:underline">%s</a>|}
                  (html_escape maps_url)
                  (html_escape (venue.address_street ^ ", " ^ venue.address_city ^ 
                    (if venue.address_state <> "" then ", " ^ venue.address_state else "") ^ 
                    ", " ^ venue.address_country)))
              ] ();
              (* Phone *)
              H.div ~class_:"flex items-center gap-2" ~children:[
                H.div ~class_:"w-4 h-4 text-gray-600 dark:text-gray-400" ~children:[
                  icon "phone"
                ] ();
                (match venue.phone with
                 | Some phone when phone <> "" ->
                   H.a ~href:("tel:" ^ phone) ~class_:"text-primary-600 dark:text-primary-400 hover:underline" ~children:[
                     H.text phone
                   ] ()
                 | _ ->
                   H.span ~class_:"text-gray-500 dark:text-gray-500 italic text-sm" ~children:[
                     H.text "No phone listed"
                   ] ())
              ] ();
              (* Coordinates *)
              H.div ~class_:"flex items-center gap-2" ~children:[
                H.div ~class_:"w-4 h-4 text-gray-600 dark:text-gray-400" ~children:[
                  icon "crosshair"
                ] ();
                (match venue.lat, venue.lng with
                 | Some lat, Some lng ->
                   let coords_url = Printf.sprintf "https://www.openstreetmap.org/?mlat=%f&mlon=%f&zoom=17" lat lng in
                   H.fragment [
                     (* Shown to non-logged-in users *)
                     H.span ~id:"coords-placeholder" ~class_:"text-gray-600 dark:text-gray-400 text-sm" ~children:[
                       H.text tr.coordinates_set
                     ] ();
                     (* Shown to logged-in users only - hidden by default, revealed by JS *)
                     H.raw (Printf.sprintf
                       {|<a id="coords-value" href="%s" target="_blank" rel="noopener noreferrer" class="hidden text-primary-600 dark:text-primary-400 hover:underline font-mono text-sm" title="Verify coordinates on OpenStreetMap">%.6f, %.6f</a>|}
                       (html_escape coords_url) lat lng)
                   ]
                  | _ ->
                    H.span ~class_:"text-yellow-600 dark:text-yellow-400 text-sm" ~children:[
                      H.text tr.no_coordinates
                    ] ())
              ] ()
            ] ();

            (* Links *)
            H.div ~class_:"pt-3 border-t-2 border-gray-200 dark:border-gray-700" ~children:[
              H.h4 ~class_:"text-sm font-semibold font-heading text-gray-700 dark:text-gray-400 mb-2" ~children:[
                H.text tr.links
              ] ();
              H.div ~class_:"flex flex-wrap gap-3" ~children:[
                (match venue.website with
                 | Some url when url <> "" ->
                   H.raw (Printf.sprintf 
                     {|<a href="%s" target="_blank" rel="noopener noreferrer" class="text-primary-600 dark:text-primary-400 hover:underline inline-flex items-center gap-2"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-4 h-4"><circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/></svg>Website</a>|}
                     (html_escape url))
                 | _ ->
                   H.span ~class_:"text-gray-500 dark:text-gray-500 italic text-sm inline-flex items-center gap-2" ~children:[
                     icon "globe";
                     H.text "No website"
                   ] ());
                (match venue.facebook with
                 | Some fb when fb <> "" ->
                   let fb_url = if String.length fb >= 4 && String.sub fb 0 4 = "http" then fb else "https://facebook.com/" ^ fb in
                   H.raw (Printf.sprintf 
                     {|<a href="%s" target="_blank" rel="noopener noreferrer" class="text-primary-600 dark:text-primary-400 hover:underline inline-flex items-center gap-2"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-4 h-4"><path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z"/></svg>Facebook</a>|}
                     (html_escape fb_url))
                 | _ -> H.fragment []);
                (match venue.instagram with
                 | Some ig when ig <> "" ->
                   let ig_url = if String.length ig >= 4 && String.sub ig 0 4 = "http" then ig else "https://instagram.com/" ^ ig in
                   H.raw (Printf.sprintf 
                     {|<a href="%s" target="_blank" rel="noopener noreferrer" class="text-primary-600 dark:text-primary-400 hover:underline inline-flex items-center gap-2"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-4 h-4"><rect width="20" height="20" x="2" y="2" rx="5" ry="5"/><path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z"/><line x1="17.5" x2="17.51" y1="6.5" y2="6.5"/></svg>Instagram</a>|}
                     (html_escape ig_url))
                 | _ -> H.fragment [])
              ] ()
            ] ()
          ] ()
        ] ()
      ] ();
      
      (* Recurring Event Series *)
      H.div ~class_:"retro-card bg-white dark:bg-surface-800 rounded-xl p-8 mb-6" ~children:[
        H.h3 ~class_:"text-lg font-bold font-heading text-gray-900 dark:text-white flex items-center gap-2 mb-4" ~children:[
          icon ~class_:"w-5 h-5 text-blue-600 dark:text-blue-400" "repeat";
          H.text tr.karaoke_schedule
        ] ();
        (if List.length event_series > 0 then
          H.div ~class_:"space-y-3" ~children:(
            List.map (fun (series : Api_types.event_series_embedded) ->
              H.a ~href:(I18n.url lang ("/series/" ^ series.slug))
                  ~class_:"block p-4 rounded-lg bg-gray-50 dark:bg-gray-800/50 hover:bg-blue-50 dark:hover:bg-blue-900/20 border-2 border-gray-200 dark:border-gray-700 hover:border-blue-500 transition-all" ~children:[
                H.div ~class_:"flex items-center justify-between" ~children:[
                  H.div ~children:[
                    H.div ~class_:"font-bold text-gray-900 dark:text-white mb-1" ~children:[
                      H.text series.title
                    ] ();
                    H.div ~class_:"flex items-center gap-3 text-sm text-gray-600 dark:text-gray-400" ~children:[
                      H.span ~class_:"flex items-center gap-1" ~children:[
                        icon ~class_:"w-3 h-3" "calendar";
                        H.text (String.concat ", " series.days_of_week)
                      ] ();
                      H.span ~class_:"flex items-center gap-1" ~children:[
                        icon ~class_:"w-3 h-3" "clock";
                        H.text series.start_time
                      ] ();
                      (match series.host with
                       | Some host when host <> "" ->
                         H.span ~class_:"flex items-center gap-1" ~children:[
                           icon ~class_:"w-3 h-3" "mic";
                           H.text host
                         ] ()
                       | _ -> H.fragment [])
                    ] ()
                  ] ();
                  H.div ~class_:"flex items-center gap-2" ~children:[
                    series_status_badge ~tr series.status;
                    icon ~class_:"w-5 h-5 text-gray-400" "chevron-right"
                  ] ()
                ] ()
              ] ()
            ) event_series
          ) ()
        else
          H.p ~class_:"text-gray-500 dark:text-gray-400 text-center py-4" ~children:[
            H.text tr.no_events_yet
          ] ());
        (* Add Event buttons *)
        H.div ~class_:"flex flex-wrap gap-2 mt-4 pt-4 border-t-2 border-gray-200 dark:border-gray-700" ~children:[
          H.a ~href:(I18n.url lang ("/venues/" ^ venue.slug ^ "/events/new"))
              ~class_:"px-3 py-1.5 rounded-lg text-sm font-semibold transition-all bg-blue-600 hover:bg-blue-700 text-white inline-flex items-center gap-1.5" ~children:[
            icon ~class_:"w-4 h-4" "plus";
            H.text tr.submit_new_event
          ] ();
          H.a ~href:(I18n.url lang ("/venues/" ^ venue.slug ^ "/events/oneoff"))
              ~class_:"px-3 py-1.5 rounded-lg text-sm font-semibold transition-all bg-blue-600 hover:bg-blue-700 text-white inline-flex items-center gap-1.5" ~children:[
            icon ~class_:"w-4 h-4" "calendar-plus";
            H.text tr.submit_oneoff_event
          ] ()
        ] ()
      ] ();
      
      (* Notes Box *)
      (match venue.notes with
       | Some notes when notes <> "" ->
         H.div ~class_:"retro-card bg-white dark:bg-surface-800 rounded-xl p-8 mb-6" ~children:[
           H.h3 ~class_:"text-lg font-bold font-heading text-gray-900 dark:text-white mb-4" ~children:[
             H.text tr.notes
           ] ();
           H.p ~class_:"text-lg text-gray-800 dark:text-gray-200 leading-relaxed" ~children:[
             H.text notes
           ] ()
         ] ()
       | _ -> H.fragment []);
      
      (* Contribute CTA *)
      H.div ~class_:"retro-card bg-orange-50 dark:bg-orange-500/10 rounded-xl p-8 text-center border-orange-500 mb-6" ~children:[
        H.p ~class_:"mb-4 text-gray-700 dark:text-gray-300" ~children:[
          H.text tr.know_something
        ] ();
        H.a ~href:(I18n.url lang ("/venues/" ^ venue.slug ^ "/edit"))
            ~class_:"px-5 py-3 rounded-lg text-base font-semibold transition-all bg-primary-600 hover:bg-primary-700 text-white retro-btn-primary inline-block" ~children:[
          H.text tr.suggest_an_edit
        ] ()
      ] ();
      
      (* Claim This Venue - only show if not already locked/claimed *)
      (if not venue.is_locked then
        H.div ~id:"claim-section" ~class_:"retro-card bg-purple-50 dark:bg-purple-500/10 rounded-xl p-8 border-purple-500 mb-6" ~children:[
          H.h3 ~class_:"text-lg font-bold font-heading text-gray-900 dark:text-white mb-2 flex items-center gap-2" ~children:[
            icon ~class_:"w-5 h-5 text-purple-600 dark:text-purple-400" "badge-check";
            H.text tr.claim_venue
          ] ();
          H.p ~class_:"text-sm text-gray-600 dark:text-gray-400 mb-4" ~children:[
            H.text tr.claim_venue_desc
          ] ();
          
          (* Claim form - hidden by default, shown when button clicked *)
          H.div ~id:"claim-form-container" ~class_:"hidden" ~children:[
            H.div ~class_:"space-y-4" ~children:[
              (* Business name *)
              H.div ~children:[
                H.label ~for_:"claim-business-name" ~class_:"block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1" ~children:[
                  H.text tr.claim_business_name
                ] ();
                H.input ~type_:"text" ~id:"claim-business-name" ~name:"business_name"
                  ~class_:"w-full px-4 py-2 rounded-lg border-2 border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
                  ~placeholder:tr.claim_business_name_placeholder ()
              ] ();
              
              (* Role selection *)
              H.div ~children:[
                H.label ~class_:"block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1" ~children:[
                  H.text tr.claim_role
                ] ();
                H.div ~class_:"flex gap-4" ~children:[
                  H.label ~class_:"flex items-center gap-2 cursor-pointer" ~children:[
                    H.input ~type_:"radio" ~name:"claim-role" ~value:"owner" 
                      ~class_:"text-purple-600 focus:ring-purple-500" ();
                    H.span ~class_:"text-gray-700 dark:text-gray-300" ~children:[H.text tr.claim_role_owner] ()
                  ] ();
                  H.label ~class_:"flex items-center gap-2 cursor-pointer" ~children:[
                    H.input ~type_:"radio" ~name:"claim-role" ~value:"host"
                      ~class_:"text-purple-600 focus:ring-purple-500" ();
                    H.span ~class_:"text-gray-700 dark:text-gray-300" ~children:[H.text tr.claim_role_host] ()
                  ] ()
                ] ()
              ] ();
              
              (* Verification notes *)
              H.div ~children:[
                H.label ~for_:"claim-verification" ~class_:"block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1" ~children:[
                  H.text tr.claim_verification
                ] ();
                H.textarea ~id:"claim-verification" ~name:"verification_notes" ~rows:2
                  ~class_:"w-full px-4 py-2 rounded-lg border-2 border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
                  ~placeholder:tr.claim_verification_placeholder ~children:[] ()
              ] ();
              
              (* Submit button *)
              H.button ~id:"claim-submit-btn" ~type_:"button"
                ~class_:"w-full px-5 py-3 rounded-lg text-base font-semibold transition-all bg-purple-600 hover:bg-purple-700 text-white border-2 border-purple-700 inline-flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed" ~children:[
                icon ~class_:"w-5 h-5" "send";
                H.span ~id:"claim-submit-text" ~children:[H.text tr.claim_submit] ()
              ] ()
            ] ();
            
            (* Status message *)
            H.div ~id:"claim-status" ~class_:"hidden mt-4 p-4 rounded-lg" ~children:[] ()
          ] ();
          
          (* Initial CTA button to show form *)
          H.button ~id:"claim-show-form-btn" ~type_:"button"
            ~class_:"px-5 py-3 rounded-lg text-base font-semibold transition-all bg-purple-600 hover:bg-purple-700 text-white border-2 border-purple-700 inline-flex items-center gap-2" ~children:[
            icon ~class_:"w-5 h-5" "badge-check";
            H.text tr.claim_venue
          ] ()
        ] ()
      else H.fragment []);
      
      (* Evidence Section *)
      (if List.length evidence_list > 0 then
        H.div ~class_:"retro-card bg-white dark:bg-surface-800 rounded-xl p-8 mb-6" ~children:[
          H.h3 ~class_:"text-lg font-bold font-heading text-gray-900 dark:text-white mb-4 flex items-center gap-2" ~children:[
            icon ~class_:"w-5 h-5 text-green-600 dark:text-green-400" "file-check";
            H.text tr.evidence
          ] ();
          H.div ~class_:"space-y-3" ~children:(List.map (render_evidence ~lang ~tr) evidence_list) ()
        ] ()
      else H.fragment [])
    ] ();
    
    (* JavaScript for follow venue functionality *)
    H.raw (Printf.sprintf {|
<script>
(function() {
  const venueId = '%s';
  const langCode = '%s';
  const i18n = {
    follow: '%s',
    following: '%s',
    unfollow: '%s',
    regularsCount: '%s',
    loginRequired: '%s'
  };
  
  const followBtn = document.getElementById('follow-btn');
  const followBtnText = document.getElementById('follow-btn-text');
  const regularsCount = document.getElementById('regulars-count');
  
  let isFollowing = false;
  let count = 0;
  
  // Update regulars count display
  function updateCountDisplay() {
    const text = i18n.regularsCount.replace('%%d', count.toString());
    regularsCount.textContent = text;
  }
  
  // Update button state
  function updateButton() {
    if (!Auth.isLoggedIn()) {
      followBtnText.textContent = i18n.follow;
      followBtn.onclick = function() {
        sessionStorage.setItem('auth_return_url', window.location.href);
        window.location.href = '/' + langCode + '/login';
      };
      return;
    }
    
    if (isFollowing) {
      followBtnText.textContent = i18n.following;
      followBtn.classList.remove('bg-pink-500', 'hover:bg-pink-600', 'border-pink-700');
      followBtn.classList.add('bg-gray-500', 'hover:bg-gray-600', 'border-gray-700');
      // Show unfollow on hover
      followBtn.onmouseenter = function() { followBtnText.textContent = i18n.unfollow; };
      followBtn.onmouseleave = function() { followBtnText.textContent = i18n.following; };
    } else {
      followBtnText.textContent = i18n.follow;
      followBtn.classList.add('bg-pink-500', 'hover:bg-pink-600', 'border-pink-700');
      followBtn.classList.remove('bg-gray-500', 'hover:bg-gray-600', 'border-gray-700');
      followBtn.onmouseenter = null;
      followBtn.onmouseleave = null;
    }
    
    followBtn.onclick = toggleFollow;
  }
  
  // Toggle follow status
  async function toggleFollow() {
    followBtn.disabled = true;
    
    try {
      if (isFollowing) {
        // Unfollow
        const res = await apiFetch('/api/regulars/' + venueId, { method: 'DELETE' });
        if (res.ok) {
          isFollowing = false;
          count = Math.max(0, count - 1);
        }
      } else {
        // Follow
        const res = await apiFetch('/api/regulars', {
          method: 'POST',
          body: JSON.stringify({ venue_id: venueId })
        });
        if (res.ok) {
          isFollowing = true;
          count++;
        }
      }
    } catch (err) {
      console.error('Follow error:', err);
    }
    
    updateCountDisplay();
    updateButton();
    followBtn.disabled = false;
  }
  
  // Initialize
  async function init() {
    // Fetch regulars count
    try {
      const countRes = await fetch('/api/venues/' + venueId + '/regulars-count');
      if (countRes.ok) {
        const data = await countRes.json();
        count = data.count || 0;
        updateCountDisplay();
      }
    } catch (err) {
      console.error('Failed to fetch regulars count:', err);
      updateCountDisplay();
    }
    
    // Check if user is following
    if (Auth.isLoggedIn()) {
      try {
        const regularsRes = await apiFetch('/api/regulars');
        if (regularsRes.ok) {
          const data = await regularsRes.json();
          const regulars = data.regulars || [];
          isFollowing = regulars.some(r => r.venue_id === venueId);
        }
      } catch (err) {
        console.error('Failed to check follow status:', err);
      }
    }
    
    updateButton();
  }
  
  // Wait for Auth to be available
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
  
  // Initialize Lucide icons
})();
</script>
|} venue.id lang_code
     (js_escape tr.follow_venue)
     (js_escape tr.following)
     (js_escape tr.unfollow)
     (js_escape tr.regulars_count)
     (js_escape tr.rsvp_login_required));
    
    (* JavaScript for claim venue functionality - only if not locked *)
    (if not venue.is_locked then
      H.raw (Printf.sprintf {|
<script>
(function() {
  const venueId = '%s';
  const langCode = '%s';
  const i18n = {
    submit: '%s',
    submitting: '%s',
    success: '%s',
    pending: '%s',
    error: '%s',
    loginRequired: '%s'
  };
  
  const showFormBtn = document.getElementById('claim-show-form-btn');
  const formContainer = document.getElementById('claim-form-container');
  const submitBtn = document.getElementById('claim-submit-btn');
  const submitText = document.getElementById('claim-submit-text');
  const claimStatus = document.getElementById('claim-status');
  
  if (!showFormBtn) return; // Claim section not present (venue is locked)
  
  function showStatus(message, isError) {
    claimStatus.classList.remove('hidden', 'bg-green-100', 'bg-red-100', 'bg-yellow-100',
      'text-green-700', 'text-red-700', 'text-yellow-700',
      'dark:bg-green-900/30', 'dark:bg-red-900/30', 'dark:bg-yellow-900/30',
      'dark:text-green-300', 'dark:text-red-300', 'dark:text-yellow-300');
    if (isError === 'pending') {
      claimStatus.classList.add('bg-yellow-100', 'text-yellow-700', 'dark:bg-yellow-900/30', 'dark:text-yellow-300');
    } else if (isError) {
      claimStatus.classList.add('bg-red-100', 'text-red-700', 'dark:bg-red-900/30', 'dark:text-red-300');
    } else {
      claimStatus.classList.add('bg-green-100', 'text-green-700', 'dark:bg-green-900/30', 'dark:text-green-300');
    }
    claimStatus.textContent = message;
  }
  
  // Show form when button clicked
  showFormBtn.addEventListener('click', function() {
    if (!Auth.isLoggedIn()) {
      sessionStorage.setItem('auth_return_url', window.location.href);
      window.location.href = '/' + langCode + '/login';
      return;
    }
    showFormBtn.classList.add('hidden');
    formContainer.classList.remove('hidden');
    // Re-initialize Lucide icons for the newly visible form
  });
  
  // Submit claim
  submitBtn.addEventListener('click', async function() {
    const businessName = document.getElementById('claim-business-name').value.trim();
    const roleRadios = document.querySelectorAll('input[name="claim-role"]');
    let role = null;
    roleRadios.forEach(r => { if (r.checked) role = r.value; });
    const verification = document.getElementById('claim-verification').value.trim();
    
    if (!businessName) {
      showStatus('Please enter a business name', true);
      return;
    }
    if (!role) {
      showStatus('Please select your role', true);
      return;
    }
    
    submitBtn.disabled = true;
    submitText.textContent = i18n.submitting;
    claimStatus.classList.add('hidden');
    
    try {
      const body = {
        business_name: businessName,
        role: role
      };
      if (verification) body.verification_notes = verification;
      
      const res = await apiFetch('/api/venues/' + venueId + '/claims', {
        method: 'POST',
        body: JSON.stringify(body)
      });
      
      if (res.ok) {
        showStatus(i18n.success, false);
        submitBtn.disabled = true;
        submitText.textContent = i18n.submit;
      } else if (res.status === 409) {
        showStatus(i18n.pending, 'pending');
        submitBtn.disabled = false;
        submitText.textContent = i18n.submit;
      } else {
        const data = await res.json().catch(() => ({}));
        showStatus(data.error || i18n.error, true);
        submitBtn.disabled = false;
        submitText.textContent = i18n.submit;
      }
    } catch (err) {
      console.error('Claim error:', err);
      showStatus(i18n.error, true);
      submitBtn.disabled = false;
      submitText.textContent = i18n.submit;
    }
  });
})();
</script>
|} venue.id lang_code
         (js_escape tr.claim_submit)
         (js_escape tr.submitting)
         (js_escape tr.claim_success)
         (js_escape tr.claim_pending)
         (js_escape tr.claim_error)
         (js_escape tr.rsvp_login_required))
    else H.fragment []);

    (* JavaScript to reveal coordinates for logged-in users *)
    H.raw {|
<script>
(function() {
  const placeholder = document.getElementById('coords-placeholder');
  const value = document.getElementById('coords-value');
  if (!placeholder || !value) return;

  function revealCoords() {
    if (Auth.isLoggedIn()) {
      placeholder.classList.add('hidden');
      value.classList.remove('hidden');
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', revealCoords);
  } else {
    revealCoords();
  }
})();
</script>
|}
  ]

let handler req =
  let lang = Layout.lang_of_request req in
  let tr = I18n.get lang in
  let slug = Dream.param req "slug" in
  let* venue_result = Api_client.Venues.get_by_slug ~slug () in
  match venue_result with
  | Ok venue ->
    (* event_series is embedded in venue_detail *)
    let event_series = venue.Api_types.event_series in
    let venue_type_str = match venue.venue_type with
      | Api_types.Private_rooms -> tr.type_private_rooms
      | Api_types.Public_stage -> tr.type_public_stage
      | Api_types.Both -> tr.type_both
    in
    let structured_data = generate_structured_data ~lang ~venue ~tr in
    let html = Solid_ml_ssr.Render.to_document (fun () ->
      Layout.render ~lang ~tr ~current_path:("/venues/" ^ venue.slug) ~title:venue.name
        ~description:(Printf.sprintf "%s %s, %s. %s"
          tr.karaoke_at venue.name venue.address_city venue_type_str)
        ~structured_data
        ~children:[render ~lang ~tr ~venue ~event_series ()] ()
    ) in
    Dream.html html
  | Error err ->
    Error_handler.handle_api_error ~lang ~tr ~context:"loading venue" err
