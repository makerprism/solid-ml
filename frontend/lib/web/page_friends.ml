(** Friends page - A-22 Friends System *)

module H = Solid_ml_ssr.Html
let icon = Components.icon

let render ~lang ~(tr : I18n.translations) () =
  let lang_code = I18n.lang_code lang in

  H.fragment [
    H.div ~class_:"max-w-4xl mx-auto" ~children:[
      (* Page header *)
      H.div ~class_:"mb-8" ~children:[
        H.h1 ~class_:"text-3xl md:text-4xl font-bold font-heading text-gray-900 dark:text-white mb-2" ~children:[
          H.text tr.friends_title
        ] ();
        H.p ~class_:"text-gray-600 dark:text-gray-400" ~children:[
          H.text tr.friends_subtitle
        ] ()
      ] ();

      (* Tabs *)
      H.div ~class_:"mb-6 border-b border-gray-200 dark:border-gray-700" ~children:[
        H.nav ~class_:"flex gap-6" ~children:[
          H.button ~id:"tab-friends" ~type_:"button"
            ~class_:"tab-btn pb-3 text-sm font-medium border-b-2 border-primary-600 text-primary-600 dark:text-primary-400"
            ~children:[
              H.span ~class_:"flex items-center gap-2" ~children:[
                icon ~class_:"w-4 h-4" "users";
                H.text tr.my_friends;
                H.span ~id:"friends-count" ~class_:"hidden px-1.5 py-0.5 text-xs font-bold bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded-full" ~children:[] ()
              ] ()
            ] ();
          H.button ~id:"tab-incoming" ~type_:"button"
            ~class_:"tab-btn pb-3 text-sm font-medium border-b-2 border-transparent text-gray-500 dark:text-gray-400 hover:text-primary-600 dark:hover:text-primary-400"
            ~children:[
              H.span ~class_:"flex items-center gap-2" ~children:[
                icon ~class_:"w-4 h-4" "user-plus";
                H.text tr.incoming_requests;
                H.span ~id:"incoming-count" ~class_:"hidden px-1.5 py-0.5 text-xs font-bold bg-red-500 text-white rounded-full" ~children:[] ()
              ] ()
            ] ();
          H.button ~id:"tab-outgoing" ~type_:"button"
            ~class_:"tab-btn pb-3 text-sm font-medium border-b-2 border-transparent text-gray-500 dark:text-gray-400 hover:text-primary-600 dark:hover:text-primary-400"
            ~children:[
              H.span ~class_:"flex items-center gap-2" ~children:[
                icon ~class_:"w-4 h-4" "send";
                H.text tr.outgoing_requests
              ] ()
            ] ()
        ] ()
      ] ();

      (* Search bar *)
      H.div ~class_:"mb-6" ~children:[
        H.div ~class_:"relative" ~children:[
          H.input ~type_:"text" ~id:"user-search" ~name:"search"
            ~class_:"w-full pl-10 pr-4 py-3 rounded-lg border-2 border-gray-700 dark:border-gray-600 bg-white dark:bg-surface-850 text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-400 focus:ring-2 focus:ring-primary-500 focus:border-primary-500 transition-colors"
            ~placeholder:tr.search_users_placeholder ();
          H.div ~class_:"absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none" ~children:[
            icon ~class_:"w-5 h-5 text-gray-400" "search"
          ] ()
        ] ();
        H.div ~id:"search-results" ~class_:"hidden mt-2 bg-white dark:bg-surface-800 border-2 border-gray-700 dark:border-gray-600 rounded-lg shadow-lg max-h-64 overflow-y-auto" ~children:[] ()
      ] ();

      (* Friends list section *)
      H.div ~id:"section-friends" ~class_:"section" ~children:[
        H.div ~id:"friends-loading" ~class_:"text-center py-8" ~children:[
          H.raw {|<svg class="animate-spin w-8 h-8 mx-auto text-primary-600" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path></svg>|};
          H.p ~class_:"mt-2 text-gray-600 dark:text-gray-400" ~children:[H.text tr.loading] ()
        ] ();
        H.div ~id:"friends-content" ~class_:"hidden grid gap-4" ~children:[] ();
        H.div ~id:"friends-empty" ~class_:"hidden text-center py-12" ~children:[
          H.div ~class_:"w-16 h-16 mx-auto mb-4 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center" ~children:[
            icon ~class_:"w-8 h-8 text-gray-400" "users"
          ] ();
          H.p ~class_:"text-gray-600 dark:text-gray-400 mb-2" ~children:[H.text tr.no_friends] ();
          H.p ~class_:"text-sm text-gray-500 dark:text-gray-500" ~children:[H.text tr.no_friends_desc] ()
        ] ()
      ] ();

      (* Incoming requests section *)
      H.div ~id:"section-incoming" ~class_:"section hidden" ~children:[
        H.div ~id:"incoming-loading" ~class_:"text-center py-8" ~children:[
          H.raw {|<svg class="animate-spin w-8 h-8 mx-auto text-primary-600" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path></svg>|};
          H.p ~class_:"mt-2 text-gray-600 dark:text-gray-400" ~children:[H.text tr.loading] ()
        ] ();
        H.div ~id:"incoming-content" ~class_:"hidden grid gap-4" ~children:[] ();
        H.div ~id:"incoming-empty" ~class_:"hidden text-center py-12" ~children:[
          H.div ~class_:"w-16 h-16 mx-auto mb-4 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center" ~children:[
            icon ~class_:"w-8 h-8 text-gray-400" "inbox"
          ] ();
          H.p ~class_:"text-gray-600 dark:text-gray-400" ~children:[H.text tr.no_incoming_requests] ()
        ] ()
      ] ();

      (* Outgoing requests section *)
      H.div ~id:"section-outgoing" ~class_:"section hidden" ~children:[
        H.div ~id:"outgoing-loading" ~class_:"text-center py-8" ~children:[
          H.raw {|<svg class="animate-spin w-8 h-8 mx-auto text-primary-600" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path></svg>|};
          H.p ~class_:"mt-2 text-gray-600 dark:text-gray-400" ~children:[H.text tr.loading] ()
        ] ();
        H.div ~id:"outgoing-content" ~class_:"hidden grid gap-4" ~children:[] ();
        H.div ~id:"outgoing-empty" ~class_:"hidden text-center py-12" ~children:[
          H.div ~class_:"w-16 h-16 mx-auto mb-4 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center" ~children:[
            icon ~class_:"w-8 h-8 text-gray-400" "send"
          ] ();
          H.p ~class_:"text-gray-600 dark:text-gray-400" ~children:[H.text tr.no_outgoing_requests] ()
        ] ()
      ] ()
    ] ();

    (* JavaScript for friends page *)
    H.raw (Printf.sprintf {|
<script>
(function() {
  const langCode = '%s';
  const i18n = {
    accept: '%s',
    decline: '%s',
    cancel: '%s',
    unfriend: '%s',
    unfriend_confirm: '%s',
    request_sent: '%s',
    add_friend: '%s',
    mutual_friends: '%s',
    mutual_friends_count: '%s',
    view_rsvps: '%s',
    no_users_found: '%s'
  };

  const tabs = ['friends', 'incoming', 'outgoing'];

  function switchTab(tabName) {
    tabs.forEach(tab => {
      const tabBtn = document.getElementById('tab-' + tab);
      const section = document.getElementById('section-' + tab);

      if (tab === tabName) {
        tabBtn.classList.add('border-primary-600', 'text-primary-600', 'dark:text-primary-400');
        tabBtn.classList.remove('border-transparent', 'text-gray-500', 'dark:text-gray-400');
        section.classList.remove('hidden');
      } else {
        tabBtn.classList.remove('border-primary-600', 'text-primary-600', 'dark:text-primary-400');
        tabBtn.classList.add('border-transparent', 'text-gray-500', 'dark:text-gray-400');
        section.classList.add('hidden');
      }
    });
  }

  tabs.forEach(tab => {
    document.getElementById('tab-' + tab).addEventListener('click', () => switchTab(tab));
  });

  // Render friend card
  function renderFriendCard(friend) {
    const displayName = friend.display_name || friend.username || 'User';
    const avatar = friend.avatar_url || '';
    const avatarHtml = avatar
      ? `<img src="${avatar}" alt="" class="w-12 h-12 rounded-full object-cover border-2 border-black dark:border-gray-600">`
      : `<div class="w-12 h-12 rounded-full bg-primary-100 dark:bg-primary-900/30 flex items-center justify-center text-primary-600 dark:text-primary-400 font-bold text-lg border-2 border-black dark:border-gray-600">${displayName.charAt(0).toUpperCase()}</div>`;

    return `
      <div class="retro-card bg-white dark:bg-surface-800 p-4 rounded-xl">
        <div class="flex items-center gap-4">
          ${avatarHtml}
          <div class="flex-grow min-w-0">
            <a href="/${langCode}/profile/${friend.username || friend.id}" class="font-bold text-gray-900 dark:text-white hover:text-primary-600 dark:hover:text-primary-400 truncate block">
              ${displayName}
            </a>
            ${friend.username ? `<p class="text-sm text-gray-500 dark:text-gray-400">@${friend.username}</p>` : ''}
          </div>
          <div class="flex gap-2 flex-shrink-0">
            <a href="/${langCode}/friends/${friend.id}/rsvps" class="retro-tag px-3 py-2 text-sm bg-primary-100 text-primary-700 dark:bg-orange-500/20 dark:text-orange-300 dark:border-orange-500">
              ${i18n.view_rsvps}
            </a>
            <button onclick="unfriend('${friend.id}')" class="px-3 py-2 text-sm font-bold uppercase tracking-wide text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg border-2 border-transparent hover:border-red-300 dark:hover:border-red-700 transition-colors">
              ${i18n.unfriend}
            </button>
          </div>
        </div>
      </div>
    `;
  }

  // Render incoming request card
  function renderIncomingCard(request) {
    const sender = request.sender || {};
    const displayName = sender.display_name || sender.username || 'User';
    const avatar = sender.avatar_url || '';
    const avatarHtml = avatar
      ? `<img src="${avatar}" alt="" class="w-12 h-12 rounded-full object-cover border-2 border-black dark:border-gray-600">`
      : `<div class="w-12 h-12 rounded-full bg-primary-100 dark:bg-primary-900/30 flex items-center justify-center text-primary-600 dark:text-primary-400 font-bold text-lg border-2 border-black dark:border-gray-600">${displayName.charAt(0).toUpperCase()}</div>`;

    const mutualCount = request.mutual_friend_count || 0;
    const mutualHtml = mutualCount > 0
      ? `<p class="text-sm text-gray-500 dark:text-gray-400">${i18n.mutual_friends_count.replace('%%d', mutualCount)}</p>`
      : '';

    return `
      <div class="retro-card bg-white dark:bg-surface-800 p-4 rounded-xl">
        <div class="flex items-center gap-4">
          ${avatarHtml}
          <div class="flex-grow min-w-0">
            <a href="/${langCode}/profile/${sender.username || sender.id}" class="font-bold text-gray-900 dark:text-white hover:text-primary-600 dark:hover:text-primary-400 truncate block">
              ${displayName}
            </a>
            ${sender.username ? `<p class="text-sm text-gray-500 dark:text-gray-400">@${sender.username}</p>` : ''}
            ${mutualHtml}
          </div>
          <div class="flex gap-2 flex-shrink-0">
            <button onclick="acceptRequest('${request.id}')" class="retro-btn-primary px-4 py-2 text-sm bg-success-600 hover:bg-success-700 text-white rounded-lg">
              ${i18n.accept}
            </button>
            <button onclick="declineRequest('${request.id}')" class="px-4 py-2 text-sm font-bold uppercase tracking-wide text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg border-2 border-gray-300 dark:border-gray-600 transition-colors">
              ${i18n.decline}
            </button>
          </div>
        </div>
      </div>
    `;
  }

  // Render outgoing request card
  function renderOutgoingCard(request) {
    const recipient = request.recipient || {};
    const displayName = recipient.display_name || recipient.username || 'User';
    const avatar = recipient.avatar_url || '';
    const avatarHtml = avatar
      ? `<img src="${avatar}" alt="" class="w-12 h-12 rounded-full object-cover border-2 border-black dark:border-gray-600">`
      : `<div class="w-12 h-12 rounded-full bg-secondary-100 dark:bg-secondary-900/30 flex items-center justify-center text-secondary-600 dark:text-secondary-400 font-bold text-lg border-2 border-black dark:border-gray-600">${displayName.charAt(0).toUpperCase()}</div>`;

    return `
      <div class="retro-card-alt bg-white dark:bg-surface-800 p-4 rounded-xl">
        <div class="flex items-center gap-4">
          ${avatarHtml}
          <div class="flex-grow min-w-0">
            <a href="/${langCode}/profile/${recipient.username || recipient.id}" class="font-bold text-gray-900 dark:text-white hover:text-primary-600 dark:hover:text-primary-400 truncate block">
              ${displayName}
            </a>
            ${recipient.username ? `<p class="text-sm text-gray-500 dark:text-gray-400">@${recipient.username}</p>` : ''}
            <p class="text-xs text-secondary-600 dark:text-secondary-400 font-medium uppercase tracking-wide">${i18n.request_sent}</p>
          </div>
          <button onclick="cancelRequest('${request.id}')" class="px-4 py-2 text-sm font-bold uppercase tracking-wide text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg border-2 border-gray-300 dark:border-gray-600 transition-colors">
            ${i18n.cancel}
          </button>
        </div>
      </div>
    `;
  }

  // Load friends
  async function loadFriends() {
    const loading = document.getElementById('friends-loading');
    const content = document.getElementById('friends-content');
    const empty = document.getElementById('friends-empty');
    const countBadge = document.getElementById('friends-count');

    try {
      const res = await apiFetch('/api/friends');
      if (res.ok) {
        const data = await res.json();
        const friends = data.friends || [];
        const count = data.count || friends.length;
        loading.classList.add('hidden');

        if (count > 0) {
          countBadge.textContent = count;
          countBadge.classList.remove('hidden');
        }

        if (friends.length === 0) {
          empty.classList.remove('hidden');
        } else {
          content.innerHTML = friends.map(renderFriendCard).join('');
          content.classList.remove('hidden');
        }
      }
    } catch (err) {
      console.error('Failed to load friends:', err);
      loading.classList.add('hidden');
      empty.classList.remove('hidden');
    }
  }

  // Load incoming requests
  async function loadIncoming() {
    const loading = document.getElementById('incoming-loading');
    const content = document.getElementById('incoming-content');
    const empty = document.getElementById('incoming-empty');
    const countBadge = document.getElementById('incoming-count');

    try {
      const res = await apiFetch('/api/friend-requests/incoming');
      if (res.ok) {
        const data = await res.json();
        const requests = data.requests || [];
        loading.classList.add('hidden');

        if (requests.length > 0) {
          countBadge.textContent = requests.length;
          countBadge.classList.remove('hidden');
        } else {
          countBadge.classList.add('hidden');
        }

        if (requests.length === 0) {
          empty.classList.remove('hidden');
        } else {
          content.innerHTML = requests.map(renderIncomingCard).join('');
          content.classList.remove('hidden');
        }
      }
    } catch (err) {
      console.error('Failed to load incoming requests:', err);
      loading.classList.add('hidden');
      empty.classList.remove('hidden');
    }
  }

  // Load outgoing requests
  async function loadOutgoing() {
    const loading = document.getElementById('outgoing-loading');
    const content = document.getElementById('outgoing-content');
    const empty = document.getElementById('outgoing-empty');

    try {
      const res = await apiFetch('/api/friend-requests/outgoing');
      if (res.ok) {
        const data = await res.json();
        const requests = data.requests || [];
        loading.classList.add('hidden');

        if (requests.length === 0) {
          empty.classList.remove('hidden');
        } else {
          content.innerHTML = requests.map(renderOutgoingCard).join('');
          content.classList.remove('hidden');
        }
      }
    } catch (err) {
      console.error('Failed to load outgoing requests:', err);
      loading.classList.add('hidden');
      empty.classList.remove('hidden');
    }
  }

  // Accept request
  window.acceptRequest = async function(id) {
    try {
      const res = await apiFetch('/api/friend-requests/' + id + '/accept', { method: 'POST' });
      if (res.ok) {
        loadIncoming();
        loadFriends();
      }
    } catch (err) {
      console.error('Failed to accept request:', err);
    }
  };

  // Decline request
  window.declineRequest = async function(id) {
    try {
      const res = await apiFetch('/api/friend-requests/' + id + '/decline', { method: 'POST' });
      if (res.ok) {
        loadIncoming();
      }
    } catch (err) {
      console.error('Failed to decline request:', err);
    }
  };

  // Cancel request
  window.cancelRequest = async function(id) {
    try {
      const res = await apiFetch('/api/friend-requests/' + id, { method: 'DELETE' });
      if (res.ok) {
        loadOutgoing();
      }
    } catch (err) {
      console.error('Failed to cancel request:', err);
    }
  };

  // Unfriend
  window.unfriend = async function(userId) {
    if (!confirm(i18n.unfriend_confirm)) return;
    try {
      const res = await apiFetch('/api/friends/' + userId, { method: 'DELETE' });
      if (res.ok) {
        loadFriends();
      }
    } catch (err) {
      console.error('Failed to unfriend:', err);
    }
  };

  // User search
  let searchTimeout;
  const searchInput = document.getElementById('user-search');
  const searchResults = document.getElementById('search-results');

  searchInput.addEventListener('input', function() {
    clearTimeout(searchTimeout);
    const query = this.value.trim();

    if (query.length < 2) {
      searchResults.classList.add('hidden');
      return;
    }

    searchTimeout = setTimeout(async () => {
      try {
        const res = await apiFetch('/api/users/search?q=' + encodeURIComponent(query));
        if (res.ok) {
          const data = await res.json();
          const users = data.users || [];

          if (users.length === 0) {
            searchResults.innerHTML = `<div class="p-4 text-center text-gray-500">${i18n.no_users_found}</div>`;
          } else {
            searchResults.innerHTML = users.map(user => {
              const displayName = user.display_name || user.username || 'User';
              const avatar = user.avatar_url || '';
              const avatarHtml = avatar
                ? `<img src="${avatar}" alt="" class="w-10 h-10 rounded-full object-cover">`
                : `<div class="w-10 h-10 rounded-full bg-primary-100 dark:bg-primary-900/30 flex items-center justify-center text-primary-600 dark:text-primary-400 font-bold">${displayName.charAt(0).toUpperCase()}</div>`;

              return `
                <a href="/${langCode}/profile/${user.username || user.id}" class="flex items-center gap-3 p-3 hover:bg-gray-50 dark:hover:bg-gray-700">
                  ${avatarHtml}
                  <div class="flex-grow">
                    <p class="font-medium text-gray-900 dark:text-white">${displayName}</p>
                    ${user.username ? `<p class="text-sm text-gray-500">@${user.username}</p>` : ''}
                  </div>
                </a>
              `;
            }).join('');
          }
          searchResults.classList.remove('hidden');
        }
      } catch (err) {
        console.error('Search failed:', err);
      }
    }, 300);
  });

  // Close search results when clicking outside
  document.addEventListener('click', function(e) {
    if (!searchInput.contains(e.target) && !searchResults.contains(e.target)) {
      searchResults.classList.add('hidden');
    }
  });

  // Initialize
  async function init() {
    if (!Auth.isLoggedIn()) {
      window.location.href = '/' + langCode + '/login';
      return;
    }

    loadFriends();
    loadIncoming();
    loadOutgoing();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
</script>
|} lang_code
     (Components.js_escape tr.accept_request)
     (Components.js_escape tr.decline_request)
     (Components.js_escape tr.cancel_request)
     (Components.js_escape tr.unfriend)
     (Components.js_escape tr.unfriend_confirm)
     (Components.js_escape tr.request_sent)
     (Components.js_escape tr.add_friend)
     (Components.js_escape tr.mutual_friends)
     (Components.js_escape tr.mutual_friends_count)
     (Components.js_escape tr.view_rsvps)
     (Components.js_escape tr.no_users_found))
  ]

let handler req =
  let lang = Layout.lang_of_request req in
  let tr = I18n.get lang in

  let html = Solid_ml_ssr.Render.to_document (fun () ->
    Layout.render ~lang ~tr ~current_path:"/friends"
      ~title:tr.friends_title
      ~description:tr.friends_subtitle
      ~children:[render ~lang ~tr ()] ()
  ) in
  Dream.html html

(** Friend RSVPs page - shows a friend's upcoming events *)
let render_rsvps ~lang ~(tr : I18n.translations) ~friend_id () =
  let lang_code = I18n.lang_code lang in

  H.fragment [
    H.div ~class_:"max-w-4xl mx-auto" ~children:[
      (* Page header - will be populated by JS with friend name *)
      H.div ~class_:"mb-8" ~children:[
        H.nav ~class_:"text-sm mb-4" ~children:[
          H.ol ~class_:"flex items-center gap-2 text-gray-700 dark:text-gray-400" ~children:[
            H.li ~children:[
              H.a ~href:(I18n.url lang "/") ~class_:"hover:text-primary-600 dark:hover:text-primary-400" ~children:[
                H.text tr.breadcrumb_home
              ] ()
            ] ();
            H.li ~children:[icon "chevron-right"] ();
            H.li ~children:[
              H.a ~href:(I18n.url lang "/friends") ~class_:"hover:text-primary-600 dark:hover:text-primary-400" ~children:[
                H.text tr.friends_title
              ] ()
            ] ();
            H.li ~children:[icon "chevron-right"] ();
            H.li ~id:"friend-name-breadcrumb" ~class_:"text-gray-900 dark:text-white font-semibold" ~children:[
              H.text "..."
            ] ()
          ] ()
        ] ();
        H.h1 ~id:"page-title" ~class_:"text-3xl md:text-4xl font-bold font-heading text-gray-900 dark:text-white mb-2" ~children:[
          H.text tr.view_rsvps
        ] ()
      ] ();

      (* RSVPs list *)
      H.div ~id:"rsvps-loading" ~class_:"text-center py-8" ~children:[
        H.raw {|<svg class="animate-spin w-8 h-8 mx-auto text-primary-600" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path></svg>|};
        H.p ~class_:"mt-2 text-gray-600 dark:text-gray-400" ~children:[H.text tr.loading] ()
      ] ();
      H.div ~id:"rsvps-content" ~class_:"hidden space-y-4" ~children:[] ();
      H.div ~id:"rsvps-empty" ~class_:"hidden text-center py-12" ~children:[
        H.div ~class_:"w-16 h-16 mx-auto mb-4 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center" ~children:[
          icon ~class_:"w-8 h-8 text-gray-400" "calendar-off"
        ] ();
        H.p ~class_:"text-gray-600 dark:text-gray-400" ~children:[
          H.text tr.no_rsvps
        ] ()
      ] ();
      H.div ~id:"rsvps-error" ~class_:"hidden text-center py-12" ~children:[
        H.div ~class_:"w-16 h-16 mx-auto mb-4 rounded-full bg-red-100 dark:bg-red-900/30 flex items-center justify-center" ~children:[
          icon ~class_:"w-8 h-8 text-red-500" "alert-circle"
        ] ();
        H.p ~class_:"text-red-600 dark:text-red-400" ~children:[
          H.text tr.submit_error
        ] ()
      ] ()
    ] ();

    (* JavaScript *)
    H.raw (Printf.sprintf {|
<script>
(function() {
  const friendId = '%s';
  const langCode = '%s';

  const loading = document.getElementById('rsvps-loading');
  const content = document.getElementById('rsvps-content');
  const empty = document.getElementById('rsvps-empty');
  const error = document.getElementById('rsvps-error');
  const pageTitle = document.getElementById('page-title');
  const breadcrumb = document.getElementById('friend-name-breadcrumb');

  async function init() {
    if (!Auth.isLoggedIn()) {
      window.location.href = '/' + langCode + '/login';
      return;
    }

    try {
      const res = await apiFetch('/api/friends/' + friendId + '/rsvps');
      loading.classList.add('hidden');

      if (!res.ok) {
        if (res.status === 403) {
          error.classList.remove('hidden');
          return;
        }
        throw new Error('Failed to fetch');
      }

      const data = await res.json();
      const rsvps = data.rsvps || [];
      const friendName = data.friend_name || 'Friend';

      // Update page title and breadcrumb with friend's name
      breadcrumb.textContent = friendName;
      pageTitle.textContent = friendName + "'s RSVPs";

      if (rsvps.length === 0) {
        empty.classList.remove('hidden');
      } else {
        content.innerHTML = rsvps.map(renderRsvpCard).join('');
        content.classList.remove('hidden');
      }
    } catch (err) {
      console.error('Failed to load RSVPs:', err);
      loading.classList.add('hidden');
      error.classList.remove('hidden');
    }
  }

  function renderRsvpCard(rsvp) {
    const event = rsvp.event || {};
    const venue = event.venue || {};
    return `
      <a href="/${langCode}/events/${event.slug}" class="retro-card bg-white dark:bg-surface-800 p-4 rounded-xl block hover:shadow-lg transition-shadow">
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 rounded-lg bg-primary-100 dark:bg-primary-900/30 flex items-center justify-center flex-shrink-0">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-6 h-6 text-primary-600 dark:text-primary-400"><path d="M8 2v4"/><path d="M16 2v4"/><rect width="18" height="18" x="3" y="4" rx="2"/><path d="M3 10h18"/></svg>
          </div>
          <div class="flex-grow min-w-0">
            <p class="font-bold text-gray-900 dark:text-white truncate">${event.title || 'Event'}</p>
            <p class="text-sm text-gray-500 dark:text-gray-400">${event.date || ''}</p>
            ${venue.name ? `<p class="text-sm text-gray-400 dark:text-gray-500 truncate">${venue.name}</p>` : ''}
          </div>
        </div>
      </a>
    `;
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
</script>
|} friend_id lang_code)
  ]

let rsvps_handler req =
  let lang = Layout.lang_of_request req in
  let tr = I18n.get lang in
  let friend_id = Dream.param req "user_id" in

  let html = Solid_ml_ssr.Render.to_document (fun () ->
    Layout.render ~lang ~tr ~current_path:"/friends"
      ~title:tr.view_rsvps
      ~description:tr.friends_subtitle
      ~children:[render_rsvps ~lang ~tr ~friend_id ()] ()
  ) in
  Dream.html html
