(** Contribute page. *)

module H = Solid_ml_ssr.Html
let icon = Components.icon

let section_title text =
  H.h2 ~class_:"text-2xl font-bold font-heading text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700" ~children:[
    H.text text
  ] ()

let page_title text =
  H.h1 ~class_:"text-4xl md:text-5xl font-bold font-heading text-gray-900 dark:text-white mb-4" ~children:[
    H.text text
  ] ()

let render ~lang ~(tr : I18n.translations) ~total_venues ~total_events ~countries ~needs_attention_count () =
  H.fragment [
    H.div ~class_:"max-w-4xl mx-auto px-4 py-8" ~children:[
      (* Hero Section with clear value prop *)
      H.div ~class_:"text-center mb-10" ~children:[
        page_title tr.help_wanted_title;
        H.p ~class_:"text-xl text-gray-600 dark:text-gray-400 max-w-2xl mx-auto leading-relaxed" ~children:[
          H.text tr.help_wanted_intro
        ] ();
      ] ();

      (* Stats Bar - visual impact *)
      H.div ~class_:"grid grid-cols-2 md:grid-cols-4 gap-4 mb-10" ~children:[
        H.div ~class_:"text-center p-4 bg-primary-50 dark:bg-primary-500/10 rounded-xl border-2 border-primary-200 dark:border-primary-800" ~children:[
          H.div ~class_:"text-3xl font-bold font-heading text-primary-600 dark:text-primary-400" ~children:[
            H.text (Printf.sprintf "%d" total_venues)
          ] ();
          H.div ~class_:"text-sm text-gray-600 dark:text-gray-400" ~children:[
            H.text tr.stats_venues
          ] ();
        ] ();
        H.div ~class_:"text-center p-4 bg-yellow-50 dark:bg-yellow-500/10 rounded-xl border-2 border-yellow-200 dark:border-yellow-800" ~children:[
          H.div ~class_:"text-3xl font-bold font-heading text-yellow-600 dark:text-yellow-400" ~children:[
            H.text (Printf.sprintf "%d" countries)
          ] ();
          H.div ~class_:"text-sm text-gray-600 dark:text-gray-400" ~children:[
            H.text tr.stats_countries
          ] ();
        ] ();
        H.div ~class_:"text-center p-4 bg-secondary-50 dark:bg-secondary-500/10 rounded-xl border-2 border-secondary-200 dark:border-secondary-800" ~children:[
          H.div ~class_:"text-3xl font-bold font-heading text-secondary-600 dark:text-secondary-400" ~children:[
            H.text (Printf.sprintf "%d" total_events)
          ] ();
          H.div ~class_:"text-sm text-gray-600 dark:text-gray-400" ~children:[
            H.text tr.stats_events
          ] ();
        ] ();
        H.div ~class_:"text-center p-4 bg-purple-50 dark:bg-purple-500/10 rounded-xl border-2 border-purple-200 dark:border-purple-800" ~children:[
          H.div ~class_:"text-3xl font-bold font-heading text-purple-600 dark:text-purple-400" ~children:[
            H.text (Printf.sprintf "%d" needs_attention_count)
          ] ();
          H.div ~class_:"text-sm text-gray-600 dark:text-gray-400" ~children:[
            H.text tr.stats_need_help
          ] ();
        ] ();
      ] ();

      (* Step-by-step process - How contributing works *)
      section_title tr.contribute_step_by_step;
      H.div ~class_:"grid md:grid-cols-3 gap-6 mb-10" ~children:[
        (* Step 1 *)
        H.div ~class_:"retro-card retro-card-static bg-white dark:bg-surface-800 rounded-xl p-6" ~children:[
          H.div ~class_:"flex flex-col items-center text-center" ~children:[
            H.div ~class_:"w-12 h-12 rounded-full bg-primary-100 dark:bg-primary-500/20 flex items-center justify-center mb-4" ~children:[
              icon ~class_:"w-6 h-6 text-primary-600 dark:text-primary-400" "search"
            ] ();
            H.h3 ~class_:"text-lg font-bold font-heading text-gray-900 dark:text-white mb-2" ~children:[
              H.text tr.contribute_step_1_title
            ] ();
            H.p ~class_:"text-sm text-gray-600 dark:text-gray-400 leading-relaxed" ~children:[
              H.text tr.contribute_step_1_desc
            ] ();
          ] ()
        ] ();
        (* Step 2 *)
        H.div ~class_:"retro-card-alt retro-card-static bg-white dark:bg-surface-800 rounded-xl p-6" ~children:[
          H.div ~class_:"flex flex-col items-center text-center" ~children:[
            H.div ~class_:"w-12 h-12 rounded-full bg-yellow-100 dark:bg-yellow-500/20 flex items-center justify-center mb-4" ~children:[
              icon ~class_:"w-6 h-6 text-yellow-600 dark:text-yellow-400" "clipboard-list"
            ] ();
            H.h3 ~class_:"text-lg font-bold font-heading text-gray-900 dark:text-white mb-2" ~children:[
              H.text tr.contribute_step_2_title
            ] ();
            H.p ~class_:"text-sm text-gray-600 dark:text-gray-400 leading-relaxed" ~children:[
              H.text tr.contribute_step_2_desc
            ] ();
          ] ()
        ] ();
        (* Step 3 *)
        H.div ~class_:"retro-card retro-card-static bg-white dark:bg-surface-800 rounded-xl p-6" ~children:[
          H.div ~class_:"flex flex-col items-center text-center" ~children:[
            H.div ~class_:"w-12 h-12 rounded-full bg-green-100 dark:bg-green-500/20 flex items-center justify-center mb-4" ~children:[
              icon ~class_:"w-6 h-6 text-green-600 dark:text-green-400" "check-circle"
            ] ();
            H.h3 ~class_:"text-lg font-bold font-heading text-gray-900 dark:text-white mb-2" ~children:[
              H.text tr.contribute_step_3_title
            ] ();
            H.p ~class_:"text-sm text-gray-600 dark:text-gray-400 leading-relaxed" ~children:[
              H.text tr.contribute_step_3_desc
            ] ();
          ] ()
        ] ();
      ] ();

      (* Ready to add - main CTA section *)
      H.div ~class_:"retro-card retro-card-static bg-gradient-to-br from-primary-50 to-yellow-50 dark:from-primary-500/5 dark:to-yellow-500/5 rounded-xl p-8 mb-10 border-primary-300 dark:border-primary-700" ~children:[
        H.h3 ~class_:"text-xl font-bold font-heading text-gray-900 dark:text-white mb-2 text-center" ~children:[
          H.text tr.contribute_ready_to_add
        ] ();
        H.p ~class_:"text-gray-600 dark:text-gray-400 mb-6 text-center" ~children:[
          H.text tr.contribute_ready_to_add_desc
        ] ();
        H.div ~class_:"flex flex-wrap justify-center gap-4" ~children:[
          H.a ~href:(I18n.url lang "/venues/new")
              ~class_:"px-6 py-4 rounded-xl text-lg font-bold transition-all bg-primary-600 hover:bg-primary-700 text-white retro-btn-primary inline-flex items-center gap-3" ~children:[
            icon ~class_:"w-5 h-5" "map-pin-plus";
            H.text tr.contribute_add_venue_btn
          ] ();
          H.a ~href:(I18n.url lang "/venues")
              ~class_:"px-6 py-4 rounded-xl text-lg font-bold transition-all bg-gray-200 hover:bg-gray-300 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-900 dark:text-white border-2 border-gray-700 dark:border-gray-500 inline-flex items-center gap-3" ~children:[
            icon ~class_:"w-5 h-5" "search";
            H.text tr.find_venues_to_update
          ] ();
        ] ()
      ] ();

      (* Update existing venue - secondary info *)
      H.div ~class_:"bg-blue-50 dark:bg-blue-500/10 rounded-xl p-6 mb-12 border-2 border-blue-200 dark:border-blue-800" ~children:[
        H.div ~class_:"flex items-start gap-4" ~children:[
          icon ~class_:"w-6 h-6 text-blue-600 dark:text-blue-400 flex-shrink-0 mt-1" "edit";
          H.div ~children:[
            H.h4 ~class_:"font-bold text-gray-900 dark:text-white mb-2" ~children:[
              H.text tr.contribute_update_existing
            ] ();
            H.p ~class_:"text-gray-600 dark:text-gray-400 leading-relaxed" ~children:[
              H.text tr.contribute_update_existing_desc
            ] ();
          ] ()
        ] ()
      ] ();

      (* Who Can Help - Three audience cards *)
      section_title tr.who_can_help;
      H.div ~class_:"grid md:grid-cols-3 gap-6 mb-12" ~children:[
        (* Card 1: Karaoke Fans *)
        H.div ~class_:"retro-card retro-card-static bg-white dark:bg-surface-800 rounded-xl p-6" ~children:[
          H.div ~class_:"flex flex-col items-center text-center" ~children:[
            H.div ~class_:"w-16 h-16 rounded-full bg-primary-100 dark:bg-primary-500/20 flex items-center justify-center mb-4" ~children:[
              icon ~class_:"w-8 h-8 text-primary-600 dark:text-primary-400" "heart"
            ] ();
            H.h3 ~class_:"text-lg font-bold font-heading text-gray-900 dark:text-white mb-2" ~children:[
              H.text tr.contributor_attendee_title
            ] ();
            H.p ~class_:"text-sm text-gray-600 dark:text-gray-400 leading-relaxed" ~children:[
              H.text tr.contributor_attendee_desc
            ] ();
          ] ()
        ] ();

        (* Card 2: KJs & Hosts *)
        H.div ~class_:"retro-card-alt retro-card-static bg-white dark:bg-surface-800 rounded-xl p-6" ~children:[
          H.div ~class_:"flex flex-col items-center text-center" ~children:[
            H.div ~class_:"w-16 h-16 rounded-full bg-purple-100 dark:bg-purple-500/20 flex items-center justify-center mb-4" ~children:[
              icon ~class_:"w-8 h-8 text-purple-600 dark:text-purple-400" "mic"
            ] ();
            H.h3 ~class_:"text-lg font-bold font-heading text-gray-900 dark:text-white mb-2" ~children:[
              H.text tr.contributor_kj_title
            ] ();
            H.p ~class_:"text-sm text-gray-600 dark:text-gray-400 leading-relaxed" ~children:[
              H.text tr.contributor_kj_desc
            ] ();
          ] ()
        ] ();

        (* Card 3: Regional Guides *)
        H.div ~class_:"retro-card retro-card-static bg-white dark:bg-surface-800 rounded-xl p-6" ~children:[
          H.div ~class_:"flex flex-col items-center text-center" ~children:[
            H.div ~class_:"w-16 h-16 rounded-full bg-yellow-100 dark:bg-yellow-500/20 flex items-center justify-center mb-4" ~children:[
              icon ~class_:"w-8 h-8 text-yellow-600 dark:text-yellow-400" "shield"
            ] ();
            H.h3 ~class_:"text-lg font-bold font-heading text-gray-900 dark:text-white mb-2" ~children:[
              H.text tr.contributor_guide_title
            ] ();
            H.p ~class_:"text-sm text-gray-600 dark:text-gray-400 leading-relaxed" ~children:[
              H.text tr.contributor_guide_desc
            ] ();
          ] ()
        ] ();
      ] ();

      (* Most Needed Alert *)
      H.div ~class_:"mb-10" ~children:[
        H.div ~class_:"bg-yellow-50 dark:bg-yellow-900/10 rounded-2xl p-6 border-4 border-black dark:border-yellow-600" ~style:"box-shadow: 6px 6px 0 #eab308;" ~children:[
          H.h3 ~class_:"font-bold text-yellow-900 dark:text-yellow-300 mb-2 text-lg flex items-center gap-2" ~children:[
            icon ~class_:"w-6 h-6" "alert-triangle";
            H.text tr.most_needed_title
          ] ();
          H.div ~class_:"text-base text-yellow-800 dark:text-yellow-200 leading-relaxed" ~children:[
            H.p ~class_:"leading-relaxed" ~children:[H.text tr.most_needed_desc] ()
          ] ()
        ] ()
      ] ();

      (* Ways to Contribute - visual grid with icons *)
      section_title tr.ways_to_contribute;
      H.div ~class_:"grid md:grid-cols-2 gap-6 mb-12" ~children:[
        (* Card 1: Verify Schedules *)
        H.div ~class_:"retro-card retro-card-static bg-white dark:bg-surface-800 rounded-xl p-6" ~children:[
          H.div ~class_:"flex items-start gap-4" ~children:[
            H.div ~class_:"w-12 h-12 rounded-xl bg-primary-100 dark:bg-primary-500/20 flex items-center justify-center flex-shrink-0" ~children:[
              icon ~class_:"w-6 h-6 text-primary-600 dark:text-primary-400" "calendar-check"
            ] ();
            H.div ~children:[
              H.h3 ~class_:"text-lg font-bold font-heading text-gray-900 dark:text-white mb-2" ~children:[
                H.text tr.verify_schedules
              ] ();
              H.p ~class_:"text-sm text-gray-600 dark:text-gray-400 mb-3" ~children:[
                H.text tr.verify_schedules_desc
              ] ();
              H.ul ~class_:"space-y-1 text-gray-600 dark:text-gray-400" ~children:[
                H.li ~class_:"flex items-start gap-2" ~children:[
                  icon ~class_:"w-4 h-4 text-green-500 mt-0.5 flex-shrink-0" "check";
                  H.span ~children:[H.text tr.confirm_venues_still_host] ()
                ] ();
                H.li ~class_:"flex items-start gap-2" ~children:[
                  icon ~class_:"w-4 h-4 text-green-500 mt-0.5 flex-shrink-0" "check";
                  H.span ~children:[H.text tr.update_schedule_changes] ()
                ] ();
                H.li ~class_:"flex items-start gap-2" ~children:[
                  icon ~class_:"w-4 h-4 text-green-500 mt-0.5 flex-shrink-0" "check";
                  H.span ~children:[H.text tr.report_closures] ()
                ] ();
              ] ()
            ] ()
          ] ()
        ] ();

        (* Card 2: Add New Venues *)
        H.div ~class_:"retro-card-alt retro-card-static bg-white dark:bg-surface-800 rounded-xl p-6" ~children:[
          H.div ~class_:"flex items-start gap-4" ~children:[
            H.div ~class_:"w-12 h-12 rounded-xl bg-yellow-100 dark:bg-yellow-500/20 flex items-center justify-center flex-shrink-0" ~children:[
              icon ~class_:"w-6 h-6 text-yellow-600 dark:text-yellow-400" "map-pin-plus"
            ] ();
            H.div ~children:[
              H.h3 ~class_:"text-lg font-bold font-heading text-gray-900 dark:text-white mb-2" ~children:[
                H.text tr.add_new_venues
              ] ();
              H.ul ~class_:"space-y-1 text-gray-600 dark:text-gray-400" ~children:[
                H.li ~class_:"flex items-start gap-2" ~children:[
                  icon ~class_:"w-4 h-4 text-green-500 mt-0.5 flex-shrink-0" "check";
                  H.span ~children:[H.text tr.submit_missing_venues] ()
                ] ();
                H.li ~class_:"flex items-start gap-2" ~children:[
                  icon ~class_:"w-4 h-4 text-green-500 mt-0.5 flex-shrink-0" "check";
                  H.span ~children:[H.text tr.provide_evidence] ()
                ] ();
              ] ()
            ] ()
          ] ()
        ] ();

        (* Card 3: Complete Missing Info *)
        H.div ~class_:"retro-card-alt retro-card-static bg-white dark:bg-surface-800 rounded-xl p-6" ~children:[
          H.div ~class_:"flex items-start gap-4" ~children:[
            H.div ~class_:"w-12 h-12 rounded-xl bg-purple-100 dark:bg-purple-500/20 flex items-center justify-center flex-shrink-0" ~children:[
              icon ~class_:"w-6 h-6 text-purple-600 dark:text-purple-400" "file-plus"
            ] ();
            H.div ~children:[
              H.h3 ~class_:"text-lg font-bold font-heading text-gray-900 dark:text-white mb-2" ~children:[
                H.text tr.complete_missing_info
              ] ();
              H.ul ~class_:"space-y-1 text-gray-600 dark:text-gray-400" ~children:[
                H.li ~class_:"flex items-start gap-2" ~children:[
                  icon ~class_:"w-4 h-4 text-green-500 mt-0.5 flex-shrink-0" "check";
                  H.span ~children:[H.text tr.add_website_social] ()
                ] ();
                H.li ~class_:"flex items-start gap-2" ~children:[
                  icon ~class_:"w-4 h-4 text-green-500 mt-0.5 flex-shrink-0" "check";
                  H.span ~children:[H.text tr.add_phone_numbers] ()
                ] ();
                H.li ~class_:"flex items-start gap-2" ~children:[
                  icon ~class_:"w-4 h-4 text-green-500 mt-0.5 flex-shrink-0" "check";
                  H.span ~children:[H.text tr.improve_notes_timing] ()
                ] ();
              ] ()
            ] ()
          ] ()
        ] ();

        (* Card 4: Help with Tagging *)
        H.div ~class_:"retro-card retro-card-static bg-white dark:bg-surface-800 rounded-xl p-6" ~children:[
          H.div ~class_:"flex items-start gap-4" ~children:[
            H.div ~class_:"w-12 h-12 rounded-xl bg-yellow-100 dark:bg-yellow-500/20 flex items-center justify-center flex-shrink-0" ~children:[
              icon ~class_:"w-6 h-6 text-yellow-600 dark:text-yellow-400" "tags"
            ] ();
            H.div ~children:[
              H.h3 ~class_:"text-lg font-bold font-heading text-gray-900 dark:text-white mb-2" ~children:[
                H.text tr.help_with_tagging
              ] ();
              H.ul ~class_:"space-y-1 text-gray-600 dark:text-gray-400" ~children:[
                H.li ~class_:"flex items-start gap-2" ~children:[
                  icon ~class_:"w-4 h-4 text-green-500 mt-0.5 flex-shrink-0" "check";
                  H.span ~children:[H.text tr.add_atmosphere_tags] ()
                ] ();
                H.li ~class_:"flex items-start gap-2" ~children:[
                  icon ~class_:"w-4 h-4 text-green-500 mt-0.5 flex-shrink-0" "check";
                  H.span ~children:[H.text tr.help_categorize] ()
                ] ();
              ] ()
            ] ()
          ] ()
        ] ();
      ] ();

      (* How to Contribute - clear steps *)
      section_title tr.how_to_contribute_title;
      H.div ~class_:"retro-card retro-card-static bg-gradient-to-br from-primary-50 to-yellow-50 dark:from-primary-500/5 dark:to-yellow-500/5 rounded-xl p-8 mb-12 border-primary-300 dark:border-primary-700" ~children:[
        H.div ~class_:"flex flex-col md:flex-row gap-6 items-center" ~children:[
          H.div ~class_:"flex-1" ~children:[
            H.p ~class_:"text-lg text-gray-700 dark:text-gray-300 leading-relaxed mb-4" ~children:[
              H.text tr.use_submission_forms
            ] ();
            H.p ~class_:"text-gray-600 dark:text-gray-400 leading-relaxed" ~children:[
              H.text (tr.include_evidence ^ " ");
              H.text tr.trust_regulars
            ] ();
          ] ();
          H.a ~href:(I18n.url lang "/venues/new")
              ~class_:"px-8 py-4 rounded-xl text-lg font-bold transition-all bg-primary-600 hover:bg-primary-700 text-white retro-btn-primary inline-flex items-center gap-3 flex-shrink-0" ~children:[
            icon ~class_:"w-5 h-5" "plus";
            H.text tr.submit_new_venue
          ] ()
        ] ()
      ] ();

      (* Contributor benefits - brief callout *)
      H.div ~class_:"bg-gray-50 dark:bg-gray-800/50 rounded-xl p-6 mb-12 border-2 border-gray-200 dark:border-gray-700" ~children:[
        H.div ~class_:"flex items-start gap-4" ~children:[
          icon ~class_:"w-6 h-6 text-purple-500 flex-shrink-0 mt-1" "gift";
          H.div ~children:[
            H.h4 ~class_:"font-bold text-gray-900 dark:text-white mb-2" ~children:[
              H.text tr.contributor_perks
            ] ();
            H.p ~class_:"text-gray-600 dark:text-gray-400 leading-relaxed" ~children:[
              H.text tr.contributor_perks_desc
            ] ();
          ] ()
        ] ()
      ] ();

      (* Coming Soon - Event Verification App *)
      section_title tr.coming_soon;
      H.div ~class_:"retro-card retro-card-static bg-gradient-to-br from-purple-50 to-pink-50 dark:from-purple-500/10 dark:to-pink-500/10 rounded-xl p-8 mb-12 border-purple-300 dark:border-purple-700" ~children:[
        H.div ~class_:"flex items-start gap-4 mb-6" ~children:[
          icon ~class_:"w-8 h-8 text-purple-600 dark:text-purple-400 flex-shrink-0" "smartphone";
          H.div ~children:[
            H.h3 ~class_:"text-xl font-bold font-heading text-gray-900 dark:text-white mb-2" ~children:[
              H.text tr.coming_soon_app_title
            ] ();
            H.p ~class_:"text-gray-600 dark:text-gray-400 leading-relaxed" ~children:[
              H.text tr.coming_soon_app_problem
            ] ();
          ] ()
        ] ();
        
        H.ul ~class_:"space-y-3 mb-6 ml-12" ~children:[
          H.li ~class_:"flex items-start gap-3" ~children:[
            icon ~class_:"w-5 h-5 text-purple-500 mt-0.5 flex-shrink-0" "check-circle";
            H.span ~class_:"text-gray-700 dark:text-gray-300" ~children:[H.text tr.coming_soon_app_confirm] ()
          ] ();
          H.li ~class_:"flex items-start gap-3" ~children:[
            icon ~class_:"w-5 h-5 text-purple-500 mt-0.5 flex-shrink-0" "check-circle";
            H.span ~class_:"text-gray-700 dark:text-gray-300" ~children:[H.text tr.coming_soon_app_social] ()
          ] ();
          H.li ~class_:"flex items-start gap-3" ~children:[
            icon ~class_:"w-5 h-5 text-purple-500 mt-0.5 flex-shrink-0" "check-circle";
            H.span ~class_:"text-gray-700 dark:text-gray-300" ~children:[H.text tr.coming_soon_app_realtime] ()
          ] ();
        ] ();
        
        H.div ~class_:"bg-white/50 dark:bg-gray-800/50 rounded-lg p-4 ml-12 mb-4" ~children:[
          H.p ~class_:"text-gray-700 dark:text-gray-300 font-medium" ~children:[
            H.text tr.coming_soon_community_driven
          ] ()
        ] ();
        
        H.div ~class_:"bg-white/50 dark:bg-gray-800/50 rounded-lg p-4 ml-12" ~children:[
          H.p ~class_:"text-gray-600 dark:text-gray-400 italic" ~children:[
            H.text (tr.coming_soon_help_shape ^ " ");
            H.a ~href:"mailto:feedback@karaokecrowd.com?subject=App feedback" 
                ~class_:"text-purple-600 dark:text-purple-400 hover:underline font-semibold not-italic" ~children:[
              H.text tr.tell_us_thoughts
            ] ()
          ] ()
        ] ()
      ] ();

      (* About Us - improved readability *)
      section_title tr.about_us;
      H.div ~class_:"mb-6" ~children:[
        H.div ~class_:"prose dark:prose-invert max-w-none" ~children:[
          H.p ~class_:"text-gray-700 dark:text-gray-300 leading-relaxed mb-6" ~children:[
            H.text (tr.hi_im_sabine ^ " ");
            H.strong ~children:[H.text "Sabine"] ();
            H.text " (";
            H.a ~href:"https://www.reddit.com/user/grumpi2" ~target:"_blank" ~class_:"text-purple-600 dark:text-purple-400 hover:underline" ~children:[
              H.text "/u/grumpi2"
            ] ();
            H.text (" " ^ tr.launched_directory)
          ] ();
          
          H.p ~class_:"text-gray-700 dark:text-gray-300 leading-relaxed mb-6" ~children:[
            H.text (tr.frustrated_finding_karaoke ^ " ");
            H.em ~children:[H.text tr.which_days_have_karaoke] ();
            H.text (" " ^ tr.quick_call_whatsapp)
          ] ();

          H.p ~class_:"text-gray-700 dark:text-gray-300 leading-relaxed mb-6" ~children:[
            H.text tr.building_work_of_love
          ] ();

          H.p ~class_:"text-gray-700 dark:text-gray-300 leading-relaxed mb-6" ~children:[
            H.strong ~children:[H.text tr.cant_do_without_community] ();
            H.text tr.expanding_coverage
          ] ();

          (* Monetization *)
          H.h4 ~class_:"font-bold text-gray-900 dark:text-white mb-3 flex items-center gap-2" ~children:[
            icon ~class_:"w-4 h-4" "info";
            H.text tr.monetization_promise
          ] ();
          H.ul ~class_:"space-y-2 text-gray-600 dark:text-gray-400" ~children:[
            H.li ~class_:"flex items-start gap-2" ~children:[
              icon ~class_:"w-4 h-4 text-green-500 mt-1 flex-shrink-0" "check";
              H.span ~children:[H.text tr.free_forever] ()
            ] ();
            H.li ~class_:"flex items-start gap-2" ~children:[
              icon ~class_:"w-4 h-4 text-green-500 mt-1 flex-shrink-0" "check";
              H.span ~children:[H.text tr.no_annoying_ads] ()
            ] ();
            H.li ~class_:"flex items-start gap-2" ~children:[
              icon ~class_:"w-4 h-4 text-green-500 mt-1 flex-shrink-0" "check";
              H.span ~children:[H.text tr.exploring_partnerships] ()
            ] ();
            H.li ~class_:"flex items-start gap-2" ~children:[
              icon ~class_:"w-4 h-4 text-green-500 mt-1 flex-shrink-0" "check";
              H.span ~children:[H.text tr.room_booking_someday] ()
            ] ();
          ] ()
        ] ()
      ] ();

      (* Final CTA *)
      H.div ~class_:"text-center py-8" ~children:[
        H.p ~class_:"text-xl text-gray-600 dark:text-gray-400 mb-6" ~children:[
          H.text tr.ready_to_help
        ] ();
        H.div ~class_:"flex flex-wrap justify-center gap-4" ~children:[
          H.a ~href:(I18n.url lang "/needs-attention")
              ~class_:"px-6 py-4 rounded-xl text-lg font-bold transition-all bg-primary-600 hover:bg-primary-700 text-white retro-btn-primary inline-flex items-center gap-3" ~children:[
            icon ~class_:"w-5 h-5" "search";
            H.text tr.browse_venues_needing_help
          ] ();
          H.a ~href:(I18n.url lang "/venues/new")
              ~class_:"px-6 py-4 rounded-xl text-lg font-bold transition-all bg-gray-200 hover:bg-gray-300 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-900 dark:text-white border-2 border-gray-700 dark:border-gray-500 inline-flex items-center gap-3" ~children:[
            icon ~class_:"w-5 h-5" "plus";
            H.text tr.submit_new_venue
          ] ();
        ] ()
      ] ()
    ] ()
  ]

let handler req =
  let open Lwt.Syntax in
  let lang = Layout.lang_of_request req in
  let tr = I18n.get lang in

  (* Fetch stats from API *)
  let* stats_result = Api_client.Stats.get () in

  let (total_venues, total_events, countries, needs_attention_count) = match stats_result with
    | Ok (v, e, c, n) -> (v, e, c, n)
    | Error _ -> (0, 0, 0, 0)
  in

  let html = Solid_ml_ssr.Render.to_document (fun () ->
    Layout.render ~lang ~tr ~current_path:"/contribute" ~title:tr.help_wanted_title ~description:tr.contribute_meta_desc
      ~children:[render ~lang ~tr ~total_venues ~total_events ~countries ~needs_attention_count ()] ()
  ) in
  Dream.html html
