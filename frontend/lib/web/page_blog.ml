(** Blog pages - index and individual posts *)

open Blog_types

module H = Solid_ml_ssr.Html

let icon = Components.icon

(** Featured post card - larger, more prominent styling *)
let featured_post_card ~lang ~lang_code ~(tr : I18n.translations) (post : post) =
  let blog_post_url = I18n.url lang ("/blog/" ^ post.slug) in
  H.article ~class_:"retro-card bg-white dark:bg-surface-800 rounded-2xl overflow-hidden" ~children:[
    H.a ~href:blog_post_url ~class_:"block group" ~children:[
      H.div ~class_:"flex flex-col md:flex-row" ~children:[
        (* Featured image/gradient area *)
         H.div ~class_:"bg-gradient-to-br from-primary-400 via-primary-500 to-secondary-500 dark:from-primary-600 dark:via-primary-700 dark:to-secondary-600 h-48 md:h-auto md:w-72 flex items-center justify-center flex-shrink-0 relative overflow-hidden" ~children:[
          H.div ~class_:"absolute inset-0 bg-black/10" ~children:[] ();
          icon ~class_:"w-20 h-20 text-white/40" "pen-line";
          (* Featured badge *)
          H.div ~class_:"absolute top-4 left-4" ~children:[
            H.span ~class_:"px-3 py-1 text-xs font-bold uppercase bg-white/90 dark:bg-black/50 text-primary-700 dark:text-primary-300 rounded-full shadow-lg" ~children:[
              H.text tr.blog_featured
            ] ()
          ] ()
        ] ();
        (* Content *)
        H.div ~class_:"p-6 md:p-8 flex-1 flex flex-col justify-center" ~children:[
            (* Meta info *)
            H.div ~class_:"flex items-center gap-3 text-sm text-gray-500 dark:text-gray-400 mb-3" ~children:[
              H.span ~children:[
                H.text (format_date lang_code post.date)
              ] ();
            H.span ~children:[H.text "·"] ();
            H.span ~children:[H.text (Printf.sprintf "%d %s" post.reading_time tr.blog_min_read)] ();
            H.span ~children:[H.text "·"] ();
            H.span ~children:[H.text post.author] ()
          ] ();
          
          (* Title *)
          H.h2 ~class_:"text-2xl md:text-3xl font-heading font-extrabold text-gray-900 dark:text-white group-hover:text-primary-600 dark:group-hover:text-primary-400 transition-colors mb-3" ~children:[
            H.text post.title
          ] ();
          
          (* Description *)
          (if post.description <> "" then
            H.p ~class_:"text-gray-600 dark:text-gray-400 text-lg mb-4 line-clamp-2" ~children:[
              H.text post.description
            ] ()
          else H.fragment []);
          
          (* Tags *)
          (if List.length post.tags > 0 then
            H.div ~class_:"flex flex-wrap gap-2 mb-4" ~children:(
              List.map (fun tag ->
                H.span ~class_:"retro-tag px-3 py-1 text-xs font-bold uppercase bg-primary-100 dark:bg-primary-900/30 text-primary-700 dark:text-primary-400" ~children:[
                  H.text tag
                ] ()
              ) post.tags
            ) ()
          else H.fragment []);
          
          (* Read more *)
          H.div ~class_:"flex items-center gap-2 text-primary-600 dark:text-primary-400 font-bold group-hover:gap-3 transition-all" ~children:[
            H.span ~children:[H.text tr.blog_read_more] ();
            icon ~class_:"w-5 h-5" "arrow-right"
          ] ()
        ] ()
      ] ()
    ] ()
  ] ()

(** Regular post card - compact but engaging *)
let post_card ~lang ~lang_code ~(tr : I18n.translations) (post : post) =
  let blog_post_url = I18n.url lang ("/blog/" ^ post.slug) in
  H.article ~class_:"retro-card bg-white dark:bg-surface-800 rounded-xl overflow-hidden" ~children:[
    H.a ~href:blog_post_url ~class_:"block group" ~children:[
      H.div ~class_:"flex flex-col sm:flex-row" ~children:[
        (* Colored accent bar *)
         H.div ~class_:"bg-gradient-to-b from-secondary-400 to-secondary-500 dark:from-secondary-600 dark:to-secondary-700 w-full h-2 sm:h-auto sm:w-2 flex-shrink-0" ~children:[] ();
        (* Content *)
        H.div ~class_:"p-5 flex-1" ~children:[
          H.div ~class_:"flex flex-col gap-2" ~children:[
            (* Meta info *)
            H.div ~class_:"flex items-center gap-3 text-sm text-gray-500 dark:text-gray-400" ~children:[
            H.span ~children:[
              H.text (format_date lang_code post.date)
            ] ();
              H.span ~children:[H.text "·"] ();
              H.span ~children:[H.text (Printf.sprintf "%d %s" post.reading_time tr.blog_min_read)] ()
            ] ();
            
            (* Title *)
            H.h2 ~class_:"text-xl font-heading font-bold text-gray-900 dark:text-white group-hover:text-primary-600 dark:group-hover:text-primary-400 transition-colors" ~children:[
              H.text post.title
            ] ();
            
            (* Description *)
            (if post.description <> "" then
              H.p ~class_:"text-gray-600 dark:text-gray-400 line-clamp-2 text-sm" ~children:[
                H.text post.description
              ] ()
            else H.fragment []);
            
            (* Tags and Read more row *)
            H.div ~class_:"flex items-center justify-between mt-2 flex-wrap gap-2" ~children:[
              (* Tags *)
              (if List.length post.tags > 0 then
                H.div ~class_:"flex flex-wrap gap-1" ~children:(
                  List.map (fun tag ->
                    H.span ~class_:"px-2 py-0.5 text-xs font-bold uppercase bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400 rounded" ~children:[
                      H.text tag
                    ] ()
                  ) post.tags
                ) ()
              else H.fragment []);
              
              (* Read more *)
              H.div ~class_:"flex items-center gap-1 text-primary-600 dark:text-primary-400 font-semibold text-sm" ~children:[
                H.span ~children:[H.text tr.blog_read_more] ();
                icon ~class_:"w-4 h-4" "arrow-right"
              ] ()
            ] ()
          ] ()
        ] ()
      ] ()
    ] ()
  ] ()

(** Blog index page - shows list of all posts *)
let render_index ~lang ~(tr : I18n.translations) ~(posts : post list) () =
  let lang_code = I18n.lang_code lang in
  let description = tr.blog_description in
  
  (* Blog hero section *)
  let hero = 
      H.section ~class_:"bg-gradient-to-br from-primary-50 via-secondary-50 to-gray-100 dark:from-gray-900 dark:via-gray-800 dark:to-gray-900 py-16 md:py-20 border-b-4 border-black dark:border-gray-700 relative overflow-hidden" ~children:[
      (* Decorative elements *)
      H.div ~class_:"absolute top-10 left-10 w-20 h-20 bg-primary-200 dark:bg-primary-900/30 rounded-full blur-2xl" ~children:[] ();
      H.div ~class_:"absolute bottom-10 right-10 w-32 h-32 bg-yellow-200 dark:bg-yellow-900/30 rounded-full blur-3xl" ~children:[] ();
      H.div ~class_:"container mx-auto px-6 relative" ~children:[
        H.div ~class_:"max-w-3xl mx-auto text-center" ~children:[
          H.div ~class_:"inline-flex items-center gap-2 px-4 py-2 bg-white/80 dark:bg-gray-800/80 rounded-full shadow-lg mb-6" ~children:[
            icon ~class_:"w-5 h-5 text-primary-600 dark:text-primary-400" "newspaper";
            H.span ~class_:"text-sm font-bold uppercase tracking-wide text-gray-700 dark:text-gray-300" ~children:[
              H.text tr.blog_title
            ] ()
          ] ();
          H.h1 ~class_:"text-4xl md:text-5xl lg:text-6xl font-heading font-extrabold mb-4 text-gray-900 dark:text-white" ~children:[
            H.text tr.blog_title
          ] ();
          H.p ~class_:"text-lg md:text-xl text-gray-700 dark:text-gray-300 max-w-2xl mx-auto mb-6" ~children:[
            H.text tr.blog_subtitle
          ] ();
          (* RSS feed link *)
          (let rss_url = (I18n.url lang "/blog/feed.xml") in
          H.div ~class_:"flex justify-center" ~children:[
            H.a ~href:rss_url ~class_:"inline-flex items-center gap-2 px-4 py-2 bg-secondary-500 hover:bg-secondary-600 dark:bg-secondary-600 dark:hover:bg-secondary-700 text-white rounded-lg font-semibold transition-colors shadow-lg hover:shadow-xl" ~children:[
              icon ~class_:"w-5 h-5" "rss";
              H.span ~children:[H.text tr.blog_rss_feed] ()
            ] ()
          ] ())
        ] ()
      ] ()
    ] ()
  in
  
  let content = 
    if List.length posts = 0 then
      (* Empty state *)
      H.div ~class_:"max-w-2xl mx-auto text-center py-16" ~children:[
        H.div ~class_:"mb-6" ~children:[
          icon ~class_:"w-16 h-16 text-gray-300 dark:text-gray-600 mx-auto" "file-text"
        ] ();
        H.h2 ~class_:"text-2xl font-heading font-bold mb-4 text-gray-900 dark:text-white" ~children:[
          H.text tr.blog_empty_title
        ] ();
        H.p ~class_:"text-gray-600 dark:text-gray-400" ~children:[
          H.text tr.blog_empty_text
        ] ()
      ] ()
    else
      (* Split into featured (first) and rest - using pattern matching for safety *)
      match posts with
      | [] -> H.fragment []  (* Should not happen due to check above, but defensive *)
      | featured :: rest ->
      H.div ~class_:"max-w-5xl mx-auto" ~children:[
        (* Featured post - first/newest post gets special treatment *)
        H.div ~class_:"mb-10" ~children:[
          featured_post_card ~lang ~lang_code ~tr featured
        ] ();
        
        (* Rest of posts in a grid *)
        (if List.length rest > 0 then
          H.div ~children:[
            H.h2 ~class_:"text-2xl font-heading font-bold text-gray-900 dark:text-white mb-6 flex items-center gap-3" ~children:[
              icon ~class_:"w-6 h-6 text-primary-600 dark:text-primary-400" "archive";
              H.span ~children:[H.text tr.blog_more_posts] ()
            ] ();
            H.div ~class_:"grid gap-6 md:grid-cols-2" ~children:(
              List.map (fun post -> post_card ~lang ~lang_code ~tr post) rest
            ) ()
          ] ()
        else H.fragment [])
      ] ()
  in
  
  Layout.render ~lang ~tr ~current_path:"/blog" 
    ~title:(tr.blog_title ^ " - KaraokeCrowd")
    ~description
    ~hero
    ~children:[content] ()

(** Individual blog post page *)
let render_post ~lang ~(tr : I18n.translations) ~(post : post) 
    ~(prev_post : post option) ~(next_post : post option) () =
  let lang_code = I18n.lang_code lang in
  
  (* JSON-LD structured data for Article *)
  let structured_data = Printf.sprintf {|{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "%s",
  "description": "%s",
  "author": {
    "@type": "Person",
    "name": "%s"
  },
  "datePublished": "%s",
  %s
  "publisher": {
    "@type": "Organization",
    "name": "KaraokeCrowd",
    "logo": {
      "@type": "ImageObject",
      "url": "https://karaokecrowd.com/images/og-default.png"
    }
  }
}|}
    (Components.json_escape post.title)
    (Components.json_escape post.description)
    post.author
    post.date
    (match post.last_updated_at with
     | Some date -> Printf.sprintf {|"dateModified": "%s",|} date
     | None -> "")
  in
  
  (* Blog post hero *)
  let hero =
    H.section ~class_:"bg-gradient-to-br from-primary-50 to-secondary-50 dark:from-gray-900 dark:to-gray-800 py-12 md:py-16 border-b-4 border-black dark:border-gray-700" ~children:[
      H.div ~class_:"container mx-auto px-6" ~children:[
        H.div ~class_:"max-w-3xl mx-auto" ~children:[
          (* Back to blog link *)
          H.a ~href:(I18n.url lang "/blog") ~class_:"inline-flex items-center gap-2 text-gray-600 dark:text-gray-400 hover:text-primary-600 dark:hover:text-primary-400 mb-6 transition-colors" ~children:[
            H.span ~children:[H.text "←"] ();
            H.span ~children:[H.text tr.blog_back_to_blog] ()
          ] ();
          
          (* Meta info *)
          H.div ~class_:"flex flex-wrap items-center gap-3 text-sm text-gray-600 dark:text-gray-400 mb-4" ~children:[
            H.span ~children:[
              H.text (format_date lang_code post.date)
            ] ();
            H.span ~children:[H.text "·"] ();
            H.span ~children:[H.text (Printf.sprintf "%d %s" post.reading_time tr.blog_min_read)] ();
            H.span ~children:[H.text "·"] ();
            H.span ~children:[H.text post.author] ()
          ] ();
          
          (* Title *)
          H.h1 ~class_:"text-4xl md:text-5xl font-heading font-extrabold text-gray-900 dark:text-white mb-4 leading-tight" ~children:[
            H.text post.title
          ] ();
          
          (* Description if present *)
          (if post.description <> "" then
            H.p ~class_:"text-xl text-gray-700 dark:text-gray-300 leading-relaxed" ~children:[
              H.text post.description
            ] ()
          else H.fragment []);
          
          (* Tags *)
          (if List.length post.tags > 0 then
            H.div ~class_:"flex flex-wrap gap-2 mt-6" ~children:(
              List.map (fun tag ->
                H.span ~class_:"px-3 py-1 text-xs font-bold uppercase bg-primary-100 dark:bg-primary-900/30 text-primary-700 dark:text-primary-400 rounded-full" ~children:[
                  H.text tag
                ] ()
              ) post.tags
            ) ()
          else H.fragment [])
        ] ()
      ] ()
    ] ()
  in
  
  (* Determine OG image - use custom if set, otherwise empty (Layout will use default) *)
  let og_image_url = match post.og_image with
    | Some img ->
      (* Ensure path starts with / for proper URL construction *)
      let path = if String.length img > 0 && img.[0] <> '/' then "/" ^ img else img in
      "https://karaokecrowd.com" ^ path
    | None -> ""
  in
  
  let content = H.div ~class_:"max-w-3xl mx-auto px-6" ~children:[
    (* Featured image if present *)
    (match post.og_image with
     | Some img ->
       H.img ~src:img ~alt:post.title ~class_:"w-full rounded-lg shadow-lg mb-8" ()
     | None -> H.fragment []);
    
    (* Article content with Tailwind Typography *)
    H.article ~class_:"prose prose-lg dark:prose-invert max-w-none prose-headings:font-heading prose-h2:mt-12 prose-h3:mt-10" ~children:[
      H.raw post.content_html
    ] ();
    
    (* Post navigation *)
    H.nav ~class_:"mt-12 pt-8 border-t border-gray-200 dark:border-gray-700" ~children:[
      H.div ~class_:"grid grid-cols-1 md:grid-cols-2 gap-4" ~children:[
        (* Previous post *)
        (match prev_post with
         | Some p ->
           let prev_url = I18n.url lang ("/blog/" ^ p.slug) in
           H.a ~href:prev_url ~class_:"retro-card-alt bg-white dark:bg-surface-800 rounded-lg p-4 group hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors" ~children:[
             H.div ~class_:"text-sm text-gray-500 dark:text-gray-400 mb-1" ~children:[
               H.text (tr.blog_previous ^ " ←")
             ] ();
              H.div ~class_:"font-heading font-bold text-gray-900 dark:text-white group-hover:text-secondary-600 dark:group-hover:text-secondary-400 transition-colors" ~children:[
               H.text p.title
             ] ()
           ] ()
         | None -> H.div ~children:[] ());
        
        (* Next post *)
        (match next_post with
         | Some p ->
           let next_url = I18n.url lang ("/blog/" ^ p.slug) in
           H.a ~href:next_url ~class_:"retro-card bg-white dark:bg-surface-800 rounded-lg p-4 group hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors text-right" ~children:[
             H.div ~class_:"text-sm text-gray-500 dark:text-gray-400 mb-1" ~children:[
               H.text ("→ " ^ tr.blog_next)
             ] ();
             H.div ~class_:"font-heading font-bold text-gray-900 dark:text-white group-hover:text-primary-600 dark:group-hover:text-primary-400 transition-colors" ~children:[
               H.text p.title
             ] ()
           ] ()
         | None -> H.div ~children:[] ())
      ] ()
    ] ()
  ] () in
  
  Layout.render
    ~lang
    ~tr
    ~current_path:("/blog/" ^ post.slug)
    ~title:(post.title ^ " - KaraokeCrowd Blog")
    ~description:post.description
    ~structured_data
    ~og_image:og_image_url
    ~hero
    ~children:[content] ()

(** Handler for blog index page *)
let index_handler req =
  let lang = Layout.lang_of_request req in
  let tr = I18n.get lang in
  let lang_code = I18n.lang_code lang in
  let posts = Blog_loader.load_posts lang_code in
  let html = Solid_ml_ssr.Render.to_document (fun () ->
    render_index ~lang ~tr ~posts ()
  ) in
  Dream.html html

(** Handler for individual blog post page *)
let post_handler req =
  let lang = Layout.lang_of_request req in
  let tr = I18n.get lang in
  let lang_code = I18n.lang_code lang in
  let slug = Dream.param req "slug" in
  let posts = Blog_loader.load_posts lang_code in
  
  (* Find the post by slug *)
  let post_opt = List.find_opt (fun p -> p.slug = slug) posts in
  
  match post_opt with
  | None ->
    (* Post not found - return 404 *)
    Dream.html ~status:`Not_Found 
      (Solid_ml_ssr.Render.to_document (fun () ->
        Layout.render ~lang ~tr ~current_path:("/blog/" ^ slug)
          ~title:(tr.not_found ^ " - KaraokeCrowd")
          ~description:tr.not_found
          ~children:[
            H.div ~class_:"max-w-2xl mx-auto text-center py-16" ~children:[
              H.h1 ~class_:"text-4xl font-heading font-bold mb-4 text-gray-900 dark:text-white" ~children:[
                H.text tr.not_found
              ] ();
              H.p ~class_:"text-gray-600 dark:text-gray-400 mb-8" ~children:[
                H.text "This blog post could not be found."
              ] ();
              H.a ~href:(I18n.url lang "/blog") ~class_:"inline-flex items-center gap-2 px-6 py-3 bg-primary-600 hover:bg-primary-700 text-white rounded-lg font-semibold transition-colors" ~children:[
                H.text tr.blog_back_to_blog
              ] ()
            ] ()
          ] ()
      ))
  | Some post ->
    (* Find prev and next posts for navigation *)
    let post_index = 
      let rec find_index i = function
        | [] -> None
        | p :: _ when p.slug = slug -> Some i
        | _ :: rest -> find_index (i + 1) rest
      in
      find_index 0 posts
    in
    
    let prev_post = match post_index with
      | Some i when i > 0 -> Some (List.nth posts (i - 1))
      | _ -> None
    in
    
    let next_post = match post_index with
      | Some i when i < List.length posts - 1 -> Some (List.nth posts (i + 1))
      | _ -> None
    in
    
    let html = Solid_ml_ssr.Render.to_document (fun () ->
      render_post ~lang ~tr ~post ~prev_post ~next_post ()
    ) in
    Dream.html html
