/* screens.js — all screens. Each builder returns a .screen node for the Router. */
(function () {
  'use strict';
  var W = window.W, el = W.el, Router = W.Router, Nav = W.Nav, Store = W.Store, Api = W.Api, Lang = W.Lang, toast = W.toast;
  var ALL = '__all__';

  function topbar(subtitle) {
    var pl = Store.active();
    var clock = el('div', { class: 'clock' });
    W.startClock(clock);
    return el('div', { class: 'topbar' }, [
      el('div', { class: 'logo', html: 'Wise<span>Vod</span>' }),
      pl ? el('div', { class: 'pl', text: '· ' + (subtitle || pl.name) }) : null,
      el('div', { class: 'spacer' }),
      clock
    ]);
  }
  function centerSpinner(label) {
    return el('div', { class: 'center' }, [el('div', { class: 'spinner' }), el('div', { text: label || 'Loading…' })]);
  }
  function selectedLangs(pl, cats) {
    var sel = Store.langSel(pl.id);
    if (sel) return sel;
    return Lang.defaultSelection(Lang.present(cats || []));
  }

  // ── Login ────────────────────────────────────────────────────────────────────
  function loginScreen() {
    var url = el('input', { type: 'url', placeholder: 'http://server:port', value: '' });
    var user = el('input', { type: 'text', placeholder: 'username' });
    var pass = el('input', { type: 'text', placeholder: 'password' });
    function field(label, input) {
      var f = el('div', { class: 'field focusable', onclick: function () { input.focus(); } }, [
        el('label', { text: label }), input
      ]);
      f._onFocus = function () {}; return f;
    }
    var btn = el('div', { class: 'btn primary focusable', 'data-autofocus': '1', text: 'Connect', onclick: connect });
    function connect() {
      var u = url.value.replace(/^\s+|\s+$/g, ''), n = user.value.replace(/^\s+|\s+$/g, ''), p = pass.value;
      if (!u || !n) { toast('Enter server URL and username'); return; }
      if (!/^https?:\/\//i.test(u)) u = 'http://' + u;
      btn.textContent = 'Connecting…';
      var pl = { url: u, user: n, pass: p, name: n };
      Api.auth(pl).then(function (info) {
        var ok = info && info.user_info && (info.user_info.auth === 1 || info.user_info.auth === '1');
        if (!ok) { btn.textContent = 'Connect'; toast('Login failed — check details'); return; }
        var saved = Store.addPlaylist(pl);
        if (info.user_info && info.user_info.username) { saved.name = info.user_info.username; }
        Api.clearCache();
        Router.replaceAll(homeScreen());
      }).catch(function (e) { btn.textContent = 'Connect'; toast('Connection error: ' + e.message); });
    }
    var form = el('div', { class: 'form' }, [
      el('h1', { text: 'Add your playlist' }),
      el('p', { text: 'Enter your Xtream Codes login. Press OK on a field to type.' }),
      field('Server URL', url), field('Username', user), field('Password', pass), btn
    ]);
    return el('div', { class: 'screen' }, [topbar('Sign in'), form]);
  }

  // ── Home menu ──────────────────────────────────────────────────────────────────
  function num(x) { var n = parseFloat(x); return isNaN(n) ? 0 : n; }

  // Shows a ★ badge on the poster art when the item is saved (parity with the
  // Flutter grids). type: 'vod' | 'series' | 'live'.
  function addFavBadge(art, type, id) {
    if (Store.isFav(type, id)) art.appendChild(el('div', { class: 'fav-badge', text: '★' }));
  }

  function posterCard(section, it) {
    var img = section === 'series' ? it.cover : it.stream_icon;
    var art = el('div', { class: 'art' }, el('div', { class: 'ph', text: '🎞' }));
    if (img) {
      var im = el('img', { loading: 'lazy', src: img });
      im.onerror = function () { im.remove(); };
      im.onload = function () { var ph = art.querySelector('.ph'); if (ph) ph.remove(); };
      art.appendChild(im);
    }
    addFavBadge(art, section === 'series' ? 'series' : 'vod',
      section === 'series' ? it.series_id : it.stream_id);
    return el('div', { class: 'poster focusable', onclick: function () { openItem(section, it); } }, [art, el('div', { class: 'cap', text: it.name })]);
  }

  function posterRow(title, items, section) {
    if (!items.length) return document.createTextNode('');
    var scroll = el('div', { class: 'pscroll' });
    items.forEach(function (it) { scroll.appendChild(posterCard(section, it)); });
    return el('div', { class: 'prow' }, [el('div', { class: 'pt', text: title }), scroll]);
  }

  // Row built from stored items (Continue Watching / Favourites). isCw=true →
  // tapping resumes playback; otherwise opens the detail page.
  function storedRow(title, items, isCw) {
    if (!items.length) return document.createTextNode('');
    var scroll = el('div', { class: 'pscroll' });
    items.forEach(function (h) {
      var art = el('div', { class: 'art' }, el('div', { class: 'ph', text: '🎞' }));
      if (h.icon) { var im = el('img', { loading: 'lazy', src: h.icon }); im.onerror = function () { im.remove(); }; im.onload = function () { var ph = art.querySelector('.ph'); if (ph) ph.remove(); }; art.appendChild(im); }
      if (isCw && h.duration && h.position) {
        var pct = Math.max(2, Math.min(100, Math.round(h.position / h.duration * 100)));
        art.appendChild(el('div', { class: 'pbar' }, el('i', { style: { width: pct + '%' } })));
      }
      scroll.appendChild(el('div', { class: 'poster focusable', onclick: function () { openStored(h, isCw); } }, [art, el('div', { class: 'cap', text: h.name })]));
    });
    return el('div', { class: 'prow' }, [el('div', { class: 'pt', text: title }), scroll]);
  }
  function openStored(h, isCw) {
    if (h.type === 'live') { W.Player.openLive({ stream_id: h.id, name: h.name }); return; }
    if (isCw) {
      if (h.type === 'series') W.Player.openEpisode({ name: h.seriesName || h.name }, { id: h.id, container_extension: h.ext, episode_num: h.epNum || '' });
      else W.Player.openVod({ stream_id: h.id, name: h.name, stream_icon: h.icon, container_extension: h.ext });
    } else {
      if (h.type === 'series') Router.push(seriesDetail({ series_id: h.id, name: h.name, cover: h.icon }));
      else Router.push(movieDetail({ stream_id: h.id, name: h.name, stream_icon: h.icon, container_extension: h.ext }));
    }
  }

  function heroBanner(movies) {
    var picks = movies.filter(function (m) { return m.stream_icon; }).slice();
    picks.sort(function (a, b) { return num(b.rating) - num(a.rating); });
    if (!picks.length) return el('div', { style: { height: '24px' } });
    var m = picks[0];
    return el('div', { class: 'hero' }, [
      el('div', { class: 'hbg', style: { backgroundImage: 'url("' + m.stream_icon + '")' } }),
      el('div', { class: 'hov' }),
      el('div', { class: 'hc' }, [
        el('h1', { text: m.name }),
        num(m.rating) ? el('div', { class: 'hr', text: '★ ' + m.rating }) : null,
        el('div', { class: 'hbtns' }, [
          el('div', { class: 'btn primary focusable', 'data-autofocus': '1', text: '▶  Play', onclick: function () { W.Player.openVod(m); } }),
          el('div', { class: 'btn focusable', text: 'ⓘ  More Info', onclick: function () { Router.push(movieDetail(m)); } })
        ])
      ])
    ]);
  }

  function buildRail(active) {
    function item(key, ico, label, onclick) {
      return el('div', { class: 'rail-item focusable' + (active === key ? ' active' : ''), onclick: onclick }, [el('div', { class: 'ri', text: ico }), el('div', { class: 'rl', text: label })]);
    }
    var p = Store.activeProfile();
    var prof = el('div', { class: 'rail-item focusable', onclick: function () { Router.push(W.More.profileSelect()); } }, [
      el('div', { class: 'avatar', style: { width: '40px', height: '40px', fontSize: '20px', background: (p && p.color) || '#6C5CE7' } }, (p && p.emoji) || '😀'),
      el('div', { class: 'rl', text: 'Profile' })
    ]);
    return el('div', { class: 'rail' }, [
      el('div', { class: 'rlogo', html: 'Wise<br>Vod' }),
      item('home', '🏠', 'Home', function () {}),
      item('search', '🔍', 'Search', function () { Router.push(W.More.search()); }),
      item('live', '📺', 'Live', function () { Router.push(categoriesScreen('live')); }),
      item('movies', '🎬', 'Movies', function () { Router.push(categoriesScreen('movies')); }),
      item('series', '📚', 'Series', function () { Router.push(categoriesScreen('series')); }),
      item('fav', '★', 'Saved', function () { Router.push(W.More.favourites()); }),
      item('settings', '⚙️', 'Settings', function () { Router.push(settingsScreen()); }),
      el('div', { style: { flex: '1' } }),
      prof
    ]);
  }

  function homeScreen() {
    var pl = Store.active();
    var main = el('div', { class: 'home-main' }, centerSpinner('Loading your library…'));
    var scr = el('div', { class: 'screen home' }, [buildRail('home'), main]);
    scr._onShow = function () { maybeLangPopup(); };
    Promise.all([safe(Api.vodStreams(pl, null)), safe(Api.series(pl, null)), safe(Api.vodCats(pl)), safe(Api.seriesCats(pl))]).then(function (r) {
      var movies = r[0] || [], series = r[1] || [], vcats = r[2] || [], scats = r[3] || [];
      var bV = Lang.blocked(vcats, selectedLangs(pl, vcats));
      var bS = Lang.blocked(scats, selectedLangs(pl, scats));
      movies = movies.filter(function (m) { return !bV[m.category_id]; });
      series = series.filter(function (s) { return !bS[s.category_id]; });
      var recent = movies.filter(function (m) { return m.stream_icon; }).slice();
      recent.sort(function (a, b) { return num(b.added) - num(a.added); });
      var topM = movies.filter(function (m) { return m.stream_icon && num(m.rating) > 0; }).slice();
      topM.sort(function (a, b) { return num(b.rating) - num(a.rating); });
      var topS = series.filter(function (s) { return s.cover && num(s.rating) > 0; }).slice();
      topS.sort(function (a, b) { return num(b.rating) - num(a.rating); });
      main.innerHTML = '';
      main.appendChild(heroBanner(movies));
      main.appendChild(storedRow('Continue Watching', Store.continueWatching(), true));
      main.appendChild(storedRow('Saved', Store.favs(), false));
      main.appendChild(posterRow('Recently Added', recent.slice(0, 20), 'movies'));
      main.appendChild(posterRow('Top Rated Movies', topM.slice(0, 20), 'movies'));
      main.appendChild(posterRow('Popular Series', topS.slice(0, 20), 'series'));
      // Re-focus only if the user is still on Home (didn't navigate during load).
      var top = Router.stack[Router.stack.length - 1];
      if (top && top.node === scr) { Nav.setScope(scr); Nav.focusFirst(); }
    });
    return scr;
  }

  function maybeLangPopup() {
    var pl = Store.active(); if (!pl || Store.langSeen(pl.id)) return;
    Promise.all([safe(Api.liveCats(pl)), safe(Api.vodCats(pl)), safe(Api.seriesCats(pl))]).then(function (r) {
      var all = [].concat(r[0] || [], r[1] || [], r[2] || []);
      var present = Lang.present(all);
      if (!present.length) { Store.markLangSeen(pl.id); return; }
      openLangPopup(pl.id, present, null);
    });
  }
  function safe(p) { return p.then(function (v) { return v; }, function () { return []; }); }

  // ── Categories (with language filter) ───────────────────────────────────────────
  function categoriesScreen(section) {
    var pl = Store.active();
    var titleMap = { live: 'Live TV', movies: 'Movies', series: 'Series' };
    var body = el('div', { class: 'catlist' }, centerSpinner());
    var scr = el('div', { class: 'screen' }, [topbar(titleMap[section]), el('div', { class: 'rowtitle', text: titleMap[section] }), body]);
    var fetch = section === 'live' ? Api.liveCats(pl) : section === 'movies' ? Api.vodCats(pl) : Api.seriesCats(pl);
    fetch.then(function (cats) {
      cats = cats || [];
      var sel = selectedLangs(pl, cats);
      var blocked = Lang.blocked(cats, sel);
      // Hide categories blocked by language OR manually hidden.
      var visible = cats.filter(function (c) { return !blocked[c.category_id] && !Store.isHidden(c.category_id); });
      body.innerHTML = '';
      var allName = section === 'live' ? 'All Channels' : section === 'movies' ? 'All Movies' : 'All Series';
      body.appendChild(catRow('▦', allName, '', function () { openCatList(section, ALL, allName); }, true));
      visible.forEach(function (c, i) {
        var locked = Store.isLocked(c.category_id);
        body.appendChild(catRow(locked ? '🔒' : '▣', c.category_name, '', function () {
          if (locked) {
            W.More.pinVerify('Enter PIN to open ' + c.category_name).then(function (ok) { if (ok) openCatList(section, c.category_id, c.category_name); });
          } else {
            openCatList(section, c.category_id, c.category_name);
          }
        }, false));
      });
      if (!visible.length) body.appendChild(el('div', { class: 'center', text: 'No categories for your selected languages.' }));
      Nav.setScope(scr); Nav.focusFirst();
    }, function (e) { body.innerHTML = ''; body.appendChild(el('div', { class: 'center', text: 'Failed to load: ' + e.message })); });
    return scr;
  }
  function catRow(badge, name, count, onclick, autofocus) {
    var props = { class: 'row-item focusable', onclick: onclick };
    if (autofocus) props['data-autofocus'] = '1';
    return el('div', props, [
      el('div', { class: 'badge', text: badge }),
      el('div', { class: 'name', text: name }),
      count ? el('div', { class: 'count', text: count }) : null,
      el('div', { class: 'chev', text: '›' })
    ]);
  }

  // ── Content list (channels / posters), incremental render + lazy images ──────────
  function listScreen(section, catId, catName) {
    var pl = Store.active();
    var grid = el('div', { class: 'grid' }, centerSpinner());
    var scr = el('div', { class: 'screen' }, [topbar(catName), el('div', { class: 'rowtitle', text: catName }), grid]);

    var dataP = section === 'live' ? Api.liveStreams(pl, catId === ALL ? null : catId)
      : section === 'movies' ? Api.vodStreams(pl, catId === ALL ? null : catId)
        : Api.series(pl, catId === ALL ? null : catId);
    var catsP = catId === ALL ? (section === 'live' ? Api.liveCats(pl) : section === 'movies' ? Api.vodCats(pl) : Api.seriesCats(pl)) : Promise.resolve(null);

    Promise.all([dataP, catsP.then(null, function () { return null; })]).then(function (res) {
      var items = res[0] || [], cats = res[1];
      if (catId === ALL && cats) {
        var sel = selectedLangs(pl, cats);
        var blocked = Lang.blocked(cats, sel);
        items = items.filter(function (it) { return !blocked[it.category_id]; });
      }
      grid.innerHTML = '';
      if (!items.length) { grid.appendChild(el('div', { class: 'center', text: 'Nothing here.' })); return; }
      renderGrid(grid, section, items);
      Nav.setScope(scr); Nav.focusFirst();
    }, function (e) { grid.innerHTML = ''; grid.appendChild(el('div', { class: 'center', text: 'Failed: ' + e.message })); });
    return scr;
  }

  function renderGrid(grid, section, items) {
    var BATCH = 120, rendered = 0;
    function card(it, idx) {
      var isLive = section === 'live';
      var img = isLive ? it.stream_icon : (section === 'movies' ? it.stream_icon : it.cover);
      var name = it.name;
      var art = el('div', { class: 'art' }, el('div', { class: 'ph', text: isLive ? '📡' : '🎞' }));
      if (img) {
        var im = el('img', { loading: 'lazy', src: img });
        im.onerror = function () { im.remove(); };
        im.onload = function () { var ph = art.querySelector('.ph'); if (ph) ph.remove(); };
        art.appendChild(im);
      }
      addFavBadge(art, isLive ? 'live' : (section === 'movies' ? 'vod' : 'series'),
        section === 'series' ? it.series_id : it.stream_id);
      var c = el('div', { class: 'poster focusable' + (isLive ? ' chan' : ''), onclick: function () { openItem(section, it); } }, [
        art, el('div', { class: 'cap', text: name })
      ]);
      if (idx === 0) c.setAttribute('data-autofocus', '1');
      c._idx = idx;
      c._onFocus = function () { if (idx >= rendered - 24) renderMore(); };
      return c;
    }
    function renderMore() {
      if (rendered >= items.length) return;
      var frag = document.createDocumentFragment();
      var end = Math.min(rendered + BATCH, items.length);
      for (; rendered < end; rendered++) frag.appendChild(card(items[rendered], rendered));
      grid.appendChild(frag);
    }
    renderMore();
    grid.addEventListener('scroll', function () {
      if (grid.scrollTop + grid.clientHeight > grid.scrollHeight - 700) renderMore();
    });
  }

  function openItem(section, it) {
    if (section === 'live') {
      W.Player.openLive(it);
    } else if (section === 'movies') {
      Router.push(movieDetail(it));
    } else {
      Router.push(seriesDetail(it));
    }
  }

  // Route a category open: Live uses the split preview screen (which self-pushes
  // so it can register its preview-cleanup onBack); Movies/Series use the grid.
  function openCatList(section, id, name) {
    if (section === 'live') liveListScreen(id, name);
    else Router.push(listScreen(section, id, name));
  }

  // ── Live list with mini-preview (IPTV-Smarters style) ────────────────────────────
  function liveListScreen(catId, catName) {
    var pl = Store.active();
    var pv = el('video', { muted: 'muted', autoplay: 'autoplay', playsinline: 'playsinline' });
    var pvName = el('div', { class: 'pv-name', text: catName });
    var listEl = el('div', { class: 'clist' }, centerSpinner());
    var preview = el('div', { class: 'preview' }, [
      el('div', { class: 'pv-video' }, pv), pvName,
      el('div', { class: 'pv-hint', text: 'OK = watch fullscreen   ·   🟡 = favourite' })
    ]);
    var scr = el('div', { class: 'screen' }, [topbar(catName), el('div', { class: 'live-split' }, [listEl, preview])]);

    var pc = W.Player.preview(pv);
    var pvT = null;
    function schedule(ch) { if (pvT) clearTimeout(pvT); pvT = setTimeout(function () { pvName.textContent = ch.name; pc.play(ch); }, 700); }
    function openFull(ch) { if (pvT) clearTimeout(pvT); pc.stop(); W.Player.openLive(ch); }
    function cleanup() { if (pvT) clearTimeout(pvT); pc.stop(); document.documentElement.classList.remove('previewing'); document.body.classList.remove('previewing'); }

    var dataP = Api.liveStreams(pl, catId === ALL ? null : catId);
    var catsP = catId === ALL ? Api.liveCats(pl) : Promise.resolve(null);
    Promise.all([dataP, catsP.then(null, function () { return null; })]).then(function (res) {
      var items = res[0] || [], cats = res[1];
      if (catId === ALL && cats) {
        var bl = Lang.blocked(cats, selectedLangs(pl, cats));
        items = items.filter(function (c) { return !bl[c.category_id]; });
      }
      listEl.innerHTML = '';
      if (!items.length) { listEl.appendChild(el('div', { class: 'center', text: 'No channels.' })); return; }
      renderChanList(listEl, items, schedule, openFull);
      Nav.setScope(scr); Nav.focusFirst();
    }, function (e) { listEl.innerHTML = ''; listEl.appendChild(el('div', { class: 'center', text: 'Failed: ' + e.message })); });

    // Reveal the hardware video plane in the preview region (webOS): body
    // transparent, list opaque, preview transparent.
    document.documentElement.classList.add('previewing');
    document.body.classList.add('previewing');
    scr._onShow = function () { document.documentElement.classList.add('previewing'); document.body.classList.add('previewing'); };
    Router.push(scr, { onBack: cleanup });
    return scr;
  }

  function renderChanList(container, items, schedule, openFull) {
    var BATCH = 80, rendered = 0;
    function row(ch, idx) {
      var logo = el('div', { class: 'clogo-wrap' });
      if (ch.stream_icon) { var im = el('img', { class: 'clogo', loading: 'lazy', src: ch.stream_icon }); im.onerror = function () { im.remove(); }; logo.appendChild(im); }
      var r = el('div', { class: 'crow focusable', onclick: function () { openFull(ch); } }, [
        el('div', { class: 'cnum', text: '' + (idx + 1) }), logo, el('div', { class: 'cname', text: ch.name })
      ]);
      if (Store.isFav('live', ch.stream_id)) r.appendChild(el('div', { class: 'crow-fav', text: '★' }));
      if (idx === 0) r.setAttribute('data-autofocus', '1');
      r._onFocus = function () { schedule(ch); if (idx >= rendered - 16) renderMore(); };
      return r;
    }
    function renderMore() {
      if (rendered >= items.length) return;
      var frag = document.createDocumentFragment();
      var end = Math.min(rendered + BATCH, items.length);
      for (; rendered < end; rendered++) frag.appendChild(row(items[rendered], rendered));
      container.appendChild(frag);
    }
    renderMore();
    container.addEventListener('scroll', function () { if (container.scrollTop + container.clientHeight > container.scrollHeight - 600) renderMore(); });
  }

  function favButton(type, favItem) {
    var b = el('div', { class: 'btn fav focusable' + (Store.isFav(type, favItem.id) ? ' on' : '') });
    function paint() { b.textContent = Store.isFav(type, favItem.id) ? '★  Saved' : '☆  Save'; }
    paint();
    b.onclick = function () { Store.toggleFav(favItem); b.classList.toggle('on', Store.isFav(type, favItem.id)); paint(); };
    return b;
  }

  // ── Movie detail ────────────────────────────────────────────────────────────────
  function movieDetail(it) {
    var pl = Store.active();
    var cover = el('div', { class: 'cover' });
    if (it.stream_icon) { var im = el('img', { src: it.stream_icon }); im.onerror = function () { im.remove(); }; cover.appendChild(im); }
    var resume = Store.getResume('vod', it.stream_id);
    var favItem = { type: 'vod', id: it.stream_id, name: it.name, icon: it.stream_icon, ext: it.container_extension };
    var actions = [el('div', { class: 'btn primary focusable', 'data-autofocus': '1', text: resume > 0 ? '▶  Resume' : '▶  Play', onclick: function () { W.Player.openVod(it); } })];
    if (resume > 0) actions.push(el('div', { class: 'btn focusable', text: '⟲  From start', onclick: function () { W.Player.openVod(it, true); } }));
    actions.push(favButton('vod', favItem));
    var meta = el('div', { class: 'meta' }, [
      el('h1', { text: it.name }),
      el('div', { class: 'sub', text: ratingLine(it) }),
      el('div', { class: 'plot', text: 'Loading details…' }),
      el('div', { class: 'actions' }, actions)
    ]);
    var scr = el('div', { class: 'screen' }, [topbar('Movie'), el('div', { class: 'detail' }, [cover, meta])]);
    Api.vodInfo(pl, it.stream_id).then(function (d) {
      var info = (d && d.info) || {};
      meta.querySelector('.plot').textContent = info.plot || info.description || 'No description.';
      var bits = [];
      if (info.releasedate || info.release_date) bits.push(info.releasedate || info.release_date);
      if (info.genre) bits.push(info.genre);
      if (info.duration) bits.push(info.duration);
      if (bits.length) meta.querySelector('.sub').textContent = bits.join('  ·  ');
    }, function () {});
    return scr;
  }
  function ratingLine(it) { var r = it.rating || it.rating_5based; return r ? ('★ ' + r) : ''; }

  // ── Series detail (seasons + episodes) ───────────────────────────────────────────
  function seriesDetail(it) {
    var pl = Store.active();
    var cover = el('div', { class: 'cover' });
    if (it.cover) { var im = el('img', { src: it.cover }); im.onerror = function () { im.remove(); }; cover.appendChild(im); }
    var seasonbar = el('div', { class: 'seasonbar' });
    var eps = el('div', { class: 'eps' }, centerSpinner('Loading episodes…'));
    var meta = el('div', { class: 'meta' }, [
      el('h1', { text: it.name }),
      el('div', { class: 'sub', text: ratingLine(it) }),
      el('div', { class: 'plot', text: it.plot || '' }),
      el('div', { class: 'actions' }, [favButton('series', { type: 'series', id: it.series_id, name: it.name, icon: it.cover })]),
      seasonbar, eps
    ]);
    var scr = el('div', { class: 'screen' }, [topbar('Series'), el('div', { class: 'detail' }, [cover, meta])]);
    Api.seriesInfo(pl, it.series_id).then(function (d) {
      var episodes = (d && d.episodes) || {};
      var seasons = Object.keys(episodes).sort(function (a, b) { return (+a) - (+b); });
      if (!seasons.length) { eps.innerHTML = ''; eps.appendChild(el('div', { text: 'No episodes.' })); return; }
      function showSeason(s) {
        seasonbar.querySelectorAll('.season').forEach(function (n) { n.classList.toggle('active', n._s === s); });
        eps.innerHTML = '';
        (episodes[s] || []).forEach(function (ep, i) {
          var node = el('div', { class: 'ep focusable', text: 'E' + (ep.episode_num || (i + 1)) + (ep.title ? ' · ' + ep.title : ''), onclick: function () { W.Player.openEpisode(it, ep); } });
          if (i === 0) node.setAttribute('data-autofocus', '1');
          eps.appendChild(node);
        });
        Nav.setScope(scr); Nav.focusFirst();
      }
      seasons.forEach(function (s, i) {
        var sc = el('div', { class: 'season focusable' + (i === 0 ? ' active' : ''), text: 'Season ' + s, onclick: function () { showSeason(s); } });
        sc._s = s; seasonbar.appendChild(sc);
      });
      showSeason(seasons[0]);
    }, function () { eps.innerHTML = ''; eps.appendChild(el('div', { text: 'Failed to load episodes.' })); });
    return scr;
  }

  // ── Settings ─────────────────────────────────────────────────────────────────────
  function settingsScreen() {
    var pl = Store.active();
    var list = el('div', { class: 'catlist' }, [
      catRow('🌐', 'Content languages', '', function () {
        if (!pl) { toast('Add a playlist first'); return; }
        Promise.all([safe(Api.liveCats(pl)), safe(Api.vodCats(pl)), safe(Api.seriesCats(pl))]).then(function (r) {
          var all = [].concat(r[0] || [], r[1] || [], r[2] || []);
          var present = Lang.present(all);
          if (!present.length) { toast('No language-tagged categories'); return; }
          var cur = Store.langSel(pl.id) || Lang.defaultSelection(present);
          openLangPopup(pl.id, present, cur);
        });
      }, true),
      catRow('🗂', 'Manage Live categories', '', function () { Router.push(W.More.categoryManager('live')); }, false),
      catRow('🗂', 'Manage Movie categories', '', function () { Router.push(W.More.categoryManager('movies')); }, false),
      catRow('🗂', 'Manage Series categories', '', function () { Router.push(W.More.categoryManager('series')); }, false),
      catRow('🔒', 'Parental controls (PIN)', '', function () { Router.push(W.More.parental()); }, false),
      catRow('👤', 'Switch / manage profiles', '', function () { Router.push(W.More.profileSelect()); }, false),
      catRow('🕘', 'Continue watching', '', function () { Router.push(W.More.history()); }, false),
      catRow('★', 'Favourites', '', function () { Router.push(W.More.favourites()); }, false),
      catRow('➕', 'Add / switch playlist', '', function () { Router.push(loginScreen()); }, false),
      catRow('🗑', 'Remove this playlist', '', function () {
        if (!pl) return;
        Store.removePlaylist(pl.id); Api.clearCache();
        if (Store.active()) Router.replaceAll(homeScreen()); else Router.replaceAll(loginScreen());
      }, false)
    ]);
    return el('div', { class: 'screen' }, [topbar('Settings'), el('div', { class: 'rowtitle', text: 'Settings' }), list]);
  }

  // ── Language popup ────────────────────────────────────────────────────────────────
  function openLangPopup(plId, present, current) {
    var sel = {};
    var initial = current || Lang.defaultSelection(present);
    initial.forEach(function (k) { sel[k] = 1; });
    var rows = el('div', { class: 'langlist' });
    present.forEach(function (k, i) {
      var row = el('div', { class: 'langrow focusable' + (sel[k] ? ' on' : '') }, [
        el('div', { class: 'code', text: Lang.codeFor(k) }),
        el('div', { class: 'lname', text: Lang.labelFor(k) }),
        el('div', { class: 'chk', text: sel[k] ? '✓' : '' })
      ]);
      if (i === 0) row.setAttribute('data-autofocus', '1');
      row.onclick = function () {
        if (sel[k]) { delete sel[k]; row.classList.remove('on'); row.querySelector('.chk').textContent = ''; }
        else { sel[k] = 1; row.classList.add('on'); row.querySelector('.chk').textContent = '✓'; }
      };
      rows.appendChild(row);
    });
    function save() {
      var arr = []; for (var k in sel) if (sel[k]) arr.push(k);
      Store.setLang(plId, arr); Router.back(); toast('Preferences saved');
    }
    var modal = el('div', { class: 'modal' }, [
      el('h2', { text: "Let's customize your experience" }),
      el('div', { class: 'desc', text: 'Pick the languages you want. We tailor Live TV, Movies and Series to your choice — anything without a language stays available.' }),
      rows,
      el('div', { class: 'foot' }, [
        el('div', { class: 'btn focusable', text: 'Select all', onclick: function () { present.forEach(function (k) { sel[k] = 1; }); rows.querySelectorAll('.langrow').forEach(function (n) { n.classList.add('on'); n.querySelector('.chk').textContent = '✓'; }); } }),
        el('div', { class: 'btn primary focusable', text: 'Save', onclick: save })
      ])
    ]);
    Router.push(el('div', { class: 'screen scrim' }, modal));
  }

  W.Screens = {
    login: loginScreen,
    home: homeScreen,
    categories: categoriesScreen,
    settings: settingsScreen,
    movieDetail: movieDetail,
    seriesDetail: seriesDetail,
    openItem: openItem,
    posterCard: posterCard,
    posterRow: posterRow,
    catRow: catRow,
    topbar: topbar,
    centerSpinner: centerSpinner,
    selectedLangs: selectedLangs,
    num: num,
    safe: safe
  };
})();
