/* more.js — profiles, search, favourites, history, parental PIN, category mgmt.
   Builds on the screen builders exposed by screens.js (W.Screens). */
(function () {
  'use strict';
  var W = window.W, el = W.el, Router = W.Router, Nav = W.Nav, Store = W.Store, Api = W.Api, Lang = W.Lang, toast = W.toast, S = W.Screens;
  var ALL = '__all__';
  function safe(p) { return p.then(function (v) { return v; }, function () { return []; }); }

  // ── Profiles ─────────────────────────────────────────────────────────────────
  var EMOJIS = ['😀', '😎', '🦊', '🐱', '🐯', '🦁', '🐼', '🐨', '👦', '👧', '🧑', '👩', '👨', '🚀', '⚽', '🎮'];
  var COLORS = ['#6C5CE7', '#22D3EE', '#FF5252', '#34D399', '#FBBF24', '#F472B6', '#60A5FA', '#A78BFA'];

  function avatar(p, size) {
    return el('div', { class: 'avatar', style: { width: size + 'px', height: size + 'px', background: p.color || '#6C5CE7', fontSize: Math.round(size * 0.5) + 'px' } }, p.emoji || '😀');
  }

  function profileSelectScreen() {
    var grid = el('div', { class: 'pf-grid' });
    function refresh() {
      grid.innerHTML = '';
      Store.profiles.forEach(function (p, i) {
        var tile = el('div', { class: 'pf-tile focusable', onclick: function () { Store.setActiveProfile(p.id); Router.replaceAll(S.home()); } }, [
          avatar(p, 132), el('div', { class: 'pf-name', text: p.name })
        ]);
        if (i === 0) tile.setAttribute('data-autofocus', '1');
        // OK = pick; long path to edit via the Manage screen.
        grid.appendChild(tile);
      });
      var add = el('div', { class: 'pf-tile focusable', onclick: function () { Router.push(profileEditScreen(null, refresh)); } }, [
        el('div', { class: 'avatar add', style: { width: '132px', height: '132px', fontSize: '60px' } }, '+'),
        el('div', { class: 'pf-name', text: 'Add' })
      ]);
      grid.appendChild(add);
      Nav.focusFirst();
    }
    refresh();
    return el('div', { class: 'screen pf-screen' }, [
      el('div', { class: 'pf-title', text: "Who's watching?" }), grid
    ]);
  }

  function profileEditScreen(existing, onDone) {
    var name = el('input', { type: 'text', placeholder: 'Profile name', value: existing ? existing.name : '' });
    var chosen = { emoji: existing ? existing.emoji : EMOJIS[0], color: existing ? existing.color : COLORS[0] };
    var emojiRow = el('div', { class: 'pick-row' });
    EMOJIS.forEach(function (e) {
      var b = el('div', { class: 'pick focusable' + (e === chosen.emoji ? ' on' : ''), text: e, onclick: function () { chosen.emoji = e; emojiRow.querySelectorAll('.pick').forEach(function (n) { n.classList.toggle('on', n.textContent === e); }); } });
      emojiRow.appendChild(b);
    });
    var colorRow = el('div', { class: 'pick-row' });
    COLORS.forEach(function (c) {
      var b = el('div', { class: 'pick swatch focusable' + (c === chosen.color ? ' on' : ''), style: { background: c }, onclick: function () { chosen.color = c; colorRow.querySelectorAll('.swatch').forEach(function (n) { n.classList.toggle('on', n.style.background === c || n.getAttribute('data-c') === c); }); } });
      b.setAttribute('data-c', c);
      colorRow.appendChild(b);
    });
    function saveP() {
      var nm = name.value.replace(/^\s+|\s+$/g, '') || 'Profile';
      if (existing) { existing.name = nm; existing.emoji = chosen.emoji; existing.color = chosen.color; Store.updateProfile(existing); }
      else { Store.addProfile({ name: nm, emoji: chosen.emoji, color: chosen.color }); }
      if (onDone) onDone(); Router.back();
    }
    var actions = [el('div', { class: 'btn primary focusable', 'data-autofocus': '1', text: existing ? 'Save' : 'Create', onclick: saveP })];
    if (existing && Store.profiles.length > 1) {
      actions.push(el('div', { class: 'btn focusable', text: 'Delete', onclick: function () { Store.deleteProfile(existing.id); if (onDone) onDone(); Router.back(); } }));
    }
    var form = el('div', { class: 'form' }, [
      el('h1', { text: existing ? 'Edit profile' : 'New profile' }),
      el('div', { class: 'field focusable', onclick: function () { name.focus(); } }, [el('label', { text: 'Name' }), name]),
      el('label', { class: 'flabel', text: 'Icon' }), emojiRow,
      el('label', { class: 'flabel', text: 'Colour' }), colorRow,
      el('div', { class: 'actions' }, actions)
    ]);
    return el('div', { class: 'screen' }, [S.topbar('Profile'), form]);
  }

  // ── Search ─────────────────────────────────────────────────────────────────────
  function searchScreen() {
    var pl = Store.active();
    var input = el('input', { type: 'text', placeholder: 'Search channels, movies, series…' });
    var results = el('div', { class: 'grid' }, el('div', { class: 'center', text: 'Type at least 2 characters' }));
    var data = { live: [], vod: [], series: [], bl: {}, bv: {}, bs: {} };
    Promise.all([safe(Api.liveStreams(pl, null)), safe(Api.vodStreams(pl, null)), safe(Api.series(pl, null)),
      safe(Api.liveCats(pl)), safe(Api.vodCats(pl)), safe(Api.seriesCats(pl))]).then(function (r) {
      data.live = r[0] || []; data.vod = r[1] || []; data.series = r[2] || [];
      data.bl = Lang.blocked(r[3] || [], S.selectedLangs(pl, r[3] || []));
      data.bv = Lang.blocked(r[4] || [], S.selectedLangs(pl, r[4] || []));
      data.bs = Lang.blocked(r[5] || [], S.selectedLangs(pl, r[5] || []));
    });
    function run() {
      var q = input.value.toLowerCase().replace(/^\s+|\s+$/g, '');
      results.innerHTML = '';
      if (q.length < 2) { results.appendChild(el('div', { class: 'center', text: 'Type at least 2 characters' })); return; }
      var out = [];
      data.live.forEach(function (c) { if (!data.bl[c.category_id] && (c.name || '').toLowerCase().indexOf(q) >= 0 && out.length < 60) out.push(S.posterCard('live', c)); });
      data.vod.forEach(function (m) { if (!data.bv[m.category_id] && (m.name || '').toLowerCase().indexOf(q) >= 0 && out.length < 120) out.push(S.posterCard('movies', m)); });
      data.series.forEach(function (s) { if (!data.bs[s.category_id] && (s.name || '').toLowerCase().indexOf(q) >= 0 && out.length < 180) out.push(S.posterCard('series', s)); });
      if (!out.length) { results.appendChild(el('div', { class: 'center', text: 'No results' })); return; }
      out.forEach(function (n) { results.appendChild(n); });
    }
    var debounce = null;
    input.addEventListener('input', function () { if (debounce) clearTimeout(debounce); debounce = setTimeout(run, 250); });
    var bar = el('div', { class: 'searchbar focusable', 'data-autofocus': '1', onclick: function () { input.focus(); } }, [el('span', { text: '🔍' }), input]);
    return el('div', { class: 'screen' }, [S.topbar('Search'), el('div', { class: 'searchwrap' }, bar), results]);
  }

  // ── Favourites ───────────────────────────────────────────────────────────────────
  function favouritesScreen() {
    var favs = Store.favs();
    var grid = el('div', { class: 'grid' });
    if (!favs.length) grid.appendChild(el('div', { class: 'center', text: 'No favourites yet. Press ★ on a movie or series.' }));
    favs.forEach(function (f) {
      var section = f.type === 'series' ? 'series' : f.type === 'live' ? 'live' : 'movies';
      var item = f.type === 'series' ? { series_id: f.id, name: f.name, cover: f.icon } : { stream_id: f.id, name: f.name, stream_icon: f.icon, container_extension: f.ext };
      grid.appendChild(S.posterCard(section, item));
    });
    return el('div', { class: 'screen' }, [S.topbar('Favourites'), el('div', { class: 'rowtitle', text: 'Favourites' }), grid]);
  }

  // ── Continue Watching / History ─────────────────────────────────────────────────
  function historyScreen() {
    var items = Store.history();
    var grid = el('div', { class: 'grid' });
    if (!items.length) grid.appendChild(el('div', { class: 'center', text: 'Nothing watched yet.' }));
    items.forEach(function (h) {
      var section = h.type === 'series' ? 'series' : 'movies';
      var it = h.type === 'series' ? { series_id: h.id, name: h.name, cover: h.icon } : { stream_id: h.id, name: h.name, stream_icon: h.icon, container_extension: h.ext };
      var card = S.posterCard(section, it);
      if (h.duration && h.position) {
        var pct = Math.max(2, Math.min(100, Math.round(h.position / h.duration * 100)));
        card.querySelector('.art').appendChild(el('div', { class: 'pbar' }, el('i', { style: { width: pct + '%' } })));
      }
      grid.appendChild(card);
    });
    var clear = el('div', { class: 'btn focusable', text: 'Clear history', onclick: function () { Store.clearHistory(); Router.back(); } });
    return el('div', { class: 'screen' }, [S.topbar('Continue Watching'),
      el('div', { class: 'rowhead' }, [el('div', { class: 'rowtitle', text: 'Continue Watching' }), clear]), grid]);
  }

  // ── Parental PIN ────────────────────────────────────────────────────────────────
  // Returns a Promise<boolean> — resolves true when the correct PIN is entered.
  function pinVerify(title) {
    return new Promise(function (resolve) {
      if (!Store.hasPin()) { resolve(true); return; }
      openPinPad(title || 'Enter PIN', function (entered) {
        if (entered === Store.pin()) { Router.back(); resolve(true); }
        else { toast('Wrong PIN'); return false; }
      }, function () { resolve(false); });
    });
  }

  function openPinPad(title, onSubmit, onCancel) {
    var val = '';
    var dots = el('div', { class: 'pin-dots' });
    function render() { dots.innerHTML = ''; for (var i = 0; i < 4; i++) dots.appendChild(el('div', { class: 'pin-dot' + (i < val.length ? ' on' : '') })); }
    render();
    function press(d) {
      if (d === 'del') { val = val.slice(0, -1); }
      else if (val.length < 4) { val += d; }
      render();
      if (val.length === 4) { var ok = onSubmit(val); if (ok === false) { val = ''; render(); } }
    }
    var pad = el('div', { class: 'pinpad' });
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'].forEach(function (k, i) {
      if (k === '') { pad.appendChild(el('div', {})); return; }
      var b = el('div', { class: 'pinkey focusable', text: k === 'del' ? '⌫' : k, onclick: function () { press(k); } });
      if (i === 0) b.setAttribute('data-autofocus', '1');
      pad.appendChild(b);
    });
    var modal = el('div', { class: 'modal pin-modal' }, [el('h2', { text: title }), dots, pad]);
    Router.push(el('div', { class: 'screen scrim' }, modal), { onBack: function () { if (onCancel) onCancel(); } });
  }

  function parentalScreen() {
    var rows = el('div', { class: 'catlist' });
    function refresh() {
      rows.innerHTML = '';
      if (Store.hasPin()) {
        rows.appendChild(S.catRow('🔑', 'Change PIN', '', function () { setNewPin(); }, true));
        rows.appendChild(S.catRow('🔓', 'Remove PIN', '', function () {
          pinVerify('Enter current PIN').then(function (ok) { if (ok) { Store.clearPin(); toast('PIN removed'); refresh(); Nav.focusFirst(); } });
        }, false));
      } else {
        rows.appendChild(S.catRow('🔒', 'Set a PIN', '', function () { setNewPin(); }, true));
      }
      Nav.focusFirst();
    }
    function setNewPin() {
      openPinPad('Enter a new 4-digit PIN', function (p1) {
        Router.back();
        openPinPad('Confirm PIN', function (p2) {
          if (p2 === p1) { Store.setPin(p1); Router.back(); toast('PIN saved'); refresh(); }
          else { toast('PINs do not match'); return false; }
        });
        return true;
      });
    }
    refresh();
    return el('div', { class: 'screen' }, [S.topbar('Parental Controls'), el('div', { class: 'rowtitle', text: 'Parental Controls' }), rows]);
  }

  // ── Category manager (hide / lock / reorder) ─────────────────────────────────────
  function categoryManagerScreen(section) {
    var pl = Store.active();
    var titleMap = { live: 'Live TV', movies: 'Movies', series: 'Series' };
    var list = el('div', { class: 'catlist' }, S.centerSpinner());
    var fetch = section === 'live' ? Api.liveCats(pl) : section === 'movies' ? Api.vodCats(pl) : Api.seriesCats(pl);
    var scr = el('div', { class: 'screen' }, [S.topbar('Manage ' + titleMap[section]), el('div', { class: 'rowtitle', text: 'Manage ' + titleMap[section] + ' categories' }), list]);
    fetch.then(function (cats) {
      cats = (cats || []).slice();
      // apply saved order
      var order = Store.catOrder(section);
      if (order.length) {
        var map = {}; cats.forEach(function (c) { map[c.category_id] = c; });
        var sorted = []; order.forEach(function (id) { if (map[id]) { sorted.push(map[id]); delete map[id]; } });
        cats.forEach(function (c) { if (map[c.category_id]) sorted.push(c); });
        cats = sorted;
      }
      function persistOrder() { Store.setCatOrder(section, cats.map(function (c) { return c.category_id; })); }
      function render() {
        list.innerHTML = '';
        cats.forEach(function (c, i) {
          var hidden = Store.isHidden(c.category_id), locked = Store.isLocked(c.category_id);
          var row = el('div', { class: 'mrow focusable' }, [
            el('div', { class: 'name', text: c.category_name }),
            el('div', { class: 'tag' + (hidden ? ' on' : ''), text: hidden ? 'Hidden' : 'Shown' }),
            el('div', { class: 'tag' + (locked ? ' on' : ''), text: locked ? '🔒' : '🔓' })
          ]);
          if (i === 0) row.setAttribute('data-autofocus', '1');
          // OK cycles: show → hide; long-press not available, so use a small menu.
          row.onclick = function () { openCatMenu(c, i); };
          list.appendChild(row);
        });
        Nav.setScope(scr); Nav.focusFirst();
      }
      function openCatMenu(c, idx) {
        var opts = el('div', { class: 'modal' }, [
          el('h2', { text: c.category_name }),
          menuBtn(Store.isHidden(c.category_id) ? 'Show category' : 'Hide category', function () { Store.toggleHidden(c.category_id); Router.back(); render(); }, true),
          menuBtn(Store.isLocked(c.category_id) ? 'Unlock (remove PIN lock)' : 'Lock with PIN', function () {
            if (!Store.isLocked(c.category_id) && !Store.hasPin()) { toast('Set a PIN first (Settings → Parental)'); Router.back(); return; }
            Store.toggleLocked(c.category_id); Router.back(); render();
          }),
          menuBtn('Move up', function () { if (idx > 0) { var t = cats[idx - 1]; cats[idx - 1] = cats[idx]; cats[idx] = t; persistOrder(); } Router.back(); render(); }),
          menuBtn('Move down', function () { if (idx < cats.length - 1) { var t = cats[idx + 1]; cats[idx + 1] = cats[idx]; cats[idx] = t; persistOrder(); } Router.back(); render(); })
        ]);
        Router.push(el('div', { class: 'screen scrim' }, opts));
      }
      render();
    });
    return scr;
  }
  function menuBtn(label, onclick, autofocus) {
    var p = { class: 'mbtn focusable', text: label, onclick: onclick };
    if (autofocus) p['data-autofocus'] = '1';
    return el('div', p);
  }

  W.More = {
    profileSelect: profileSelectScreen,
    profileEdit: profileEditScreen,
    search: searchScreen,
    favourites: favouritesScreen,
    history: historyScreen,
    parental: parentalScreen,
    categoryManager: categoryManagerScreen,
    pinVerify: pinVerify
  };
})();
