/* core.js — DOM helpers, store, spatial D-pad navigation, screen router.
   Target: webOS Chromium ~79. No optional chaining / nullish coalescing. */
(function () {
  'use strict';
  var W = (window.W = window.W || {});

  // ── DOM helpers ────────────────────────────────────────────────────────────
  function el(tag, props, kids) {
    var e = document.createElement(tag);
    if (props) {
      for (var k in props) {
        if (!props.hasOwnProperty(k)) continue;
        var v = props[k];
        if (v == null) continue;
        if (k === 'class') e.className = v;
        else if (k === 'html') e.innerHTML = v;
        else if (k === 'text') e.textContent = v;
        else if (k === 'focusable') { if (v) e.classList.add('focusable'); }
        else if (k === 'style' && typeof v === 'object') { for (var s in v) e.style[s] = v[s]; }
        else if (k.slice(0, 2) === 'on' && typeof v === 'function') e.addEventListener(k.slice(2).toLowerCase(), v);
        else if (k === 'data' && typeof v === 'object') { for (var d in v) e.setAttribute('data-' + d, v[d]); }
        else e.setAttribute(k, v);
      }
    }
    appendKids(e, kids);
    return e;
  }
  function appendKids(e, kids) {
    if (kids == null) return;
    if (Array.isArray(kids)) { for (var i = 0; i < kids.length; i++) appendKids(e, kids[i]); }
    else if (typeof kids === 'string' || typeof kids === 'number') e.appendChild(document.createTextNode('' + kids));
    else if (kids.nodeType) e.appendChild(kids);
  }
  function $(sel, root) { return (root || document).querySelector(sel); }

  var _toastT = null;
  function toast(msg, ms) {
    var t = document.getElementById('toast');
    t.textContent = msg; t.hidden = false;
    if (_toastT) clearTimeout(_toastT);
    _toastT = setTimeout(function () { t.hidden = true; }, ms || 2200);
  }

  W.el = el; W.$ = $; W.toast = toast;

  // ── Store (localStorage-backed) ──────────────────────────────────────────────
  var LS = window.localStorage;
  function load(key, def) {
    try { var v = LS.getItem(key); return v == null ? def : JSON.parse(v); }
    catch (e) { return def; }
  }
  function save(key, val) { try { LS.setItem(key, JSON.stringify(val)); } catch (e) {} }

  function ts() { return Date.now(); }
  var Store = {
    playlists: load('w.playlists', []),       // [{id,name,url,user,pass}] (global)
    activeId: load('w.activeId', null),
    profiles: load('w.profiles', []),         // [{id,name,emoji,color}]
    activeProfileId: load('w.profile', null),
    _lang: load('w.lang', {}),                // { profileId_playlistId: {sel,seen} }
    _fav: load('w.fav', {}),                  // { profileId: [ {type,id,name,icon,ext} ] }
    _hist: load('w.hist', {}),                // { profileId: { 'type:id': item } }
    _pin: load('w.pin', {}),                  // { profileId: '1234' }
    _cat: load('w.cat', {}),                  // { profileId_playlistId: {hidden,locked,order} }

    // ── Playlists (shared across profiles) ──
    active: function () {
      var id = this.activeId, ps = this.playlists;
      for (var i = 0; i < ps.length; i++) if (ps[i].id === id) return ps[i];
      return null;
    },
    addPlaylist: function (p) {
      p.id = 'pl_' + ts();
      this.playlists.push(p); this.activeId = p.id;
      save('w.playlists', this.playlists); save('w.activeId', this.activeId);
      return p;
    },
    setActive: function (id) { this.activeId = id; save('w.activeId', id); },
    removePlaylist: function (id) {
      this.playlists = this.playlists.filter(function (p) { return p.id !== id; });
      if (this.activeId === id) this.activeId = this.playlists.length ? this.playlists[0].id : null;
      save('w.playlists', this.playlists); save('w.activeId', this.activeId);
    },

    // ── Profiles ──
    ensureProfile: function () {
      if (!this.profiles.length) {
        var p = { id: 'pf_' + ts(), name: 'Main', emoji: '😀', color: '#6C5CE7' };
        this.profiles.push(p); this.activeProfileId = p.id;
        save('w.profiles', this.profiles); save('w.profile', this.activeProfileId);
      } else if (!this.profileById(this.activeProfileId)) {
        this.activeProfileId = this.profiles[0].id; save('w.profile', this.activeProfileId);
      }
    },
    profileById: function (id) { for (var i = 0; i < this.profiles.length; i++) if (this.profiles[i].id === id) return this.profiles[i]; return null; },
    activeProfile: function () { return this.profileById(this.activeProfileId); },
    addProfile: function (p) { p.id = 'pf_' + ts(); this.profiles.push(p); save('w.profiles', this.profiles); return p; },
    updateProfile: function (p) { for (var i = 0; i < this.profiles.length; i++) if (this.profiles[i].id === p.id) this.profiles[i] = p; save('w.profiles', this.profiles); },
    deleteProfile: function (id) {
      this.profiles = this.profiles.filter(function (p) { return p.id !== id; });
      delete this._fav[id]; delete this._hist[id]; delete this._pin[id];
      save('w.fav', this._fav); save('w.hist', this._hist); save('w.pin', this._pin);
      if (this.activeProfileId === id) this.activeProfileId = this.profiles.length ? this.profiles[0].id : null;
      save('w.profiles', this.profiles); save('w.profile', this.activeProfileId);
    },
    setActiveProfile: function (id) { this.activeProfileId = id; save('w.profile', id); },

    _pk: function (plId) { return this.activeProfileId + '_' + (plId || this.activeId); },

    // ── Language prefs (per profile + playlist) ──
    langSel: function (plId) { var e = this._lang[this._pk(plId)]; return e && e.sel ? e.sel : null; },
    langSeen: function (plId) { var e = this._lang[this._pk(plId)]; return !!(e && e.seen); },
    setLang: function (plId, sel) { this._lang[this._pk(plId)] = { sel: sel, seen: true }; save('w.lang', this._lang); },
    markLangSeen: function (plId) { var k = this._pk(plId); var e = this._lang[k] || {}; e.seen = true; this._lang[k] = e; save('w.lang', this._lang); },

    // ── Favourites (per profile) ──
    favs: function () { return this._fav[this.activeProfileId] || []; },
    isFav: function (type, id) { var a = this.favs(); for (var i = 0; i < a.length; i++) if (a[i].type === type && a[i].id === id) return true; return false; },
    toggleFav: function (item) {
      var a = this._fav[this.activeProfileId] || [], idx = -1;
      for (var i = 0; i < a.length; i++) if (a[i].type === item.type && a[i].id === item.id) { idx = i; break; }
      if (idx >= 0) a.splice(idx, 1); else a.unshift(item);
      this._fav[this.activeProfileId] = a; save('w.fav', this._fav); return idx < 0;
    },

    // ── Watch history / resume (per profile) ──
    _hp: function () { if (!this._hist[this.activeProfileId]) this._hist[this.activeProfileId] = {}; return this._hist[this.activeProfileId]; },
    saveHist: function (item) {
      var h = this._hp(), key = item.type + ':' + item.id, ex = h[key];
      if (ex) { if (!item.position) item.position = ex.position; if (!item.duration) item.duration = ex.duration; }
      item.ts = ts(); h[key] = item; save('w.hist', this._hist);
    },
    setPosition: function (type, id, pos, dur) {
      var h = this._hp(), key = type + ':' + id, ex = h[key];
      if (ex) { ex.position = pos; if (dur) ex.duration = dur; ex.ts = ts(); save('w.hist', this._hist); }
    },
    getResume: function (type, id) { var e = this._hp()[type + ':' + id]; return e && e.position ? e.position : 0; },
    history: function () { var h = this._hp(), a = []; for (var k in h) if (h.hasOwnProperty(k)) a.push(h[k]); a.sort(function (x, y) { return (y.ts || 0) - (x.ts || 0); }); return a; },
    continueWatching: function () {
      return this.history().filter(function (i) {
        return (i.type === 'vod' || i.type === 'series') && (i.position || 0) > 20 && !(i.duration && i.position / i.duration > 0.95);
      }).slice(0, 20);
    },
    clearHistory: function () { this._hist[this.activeProfileId] = {}; save('w.hist', this._hist); },

    // ── Parental PIN (per profile) ──
    pin: function () { return this._pin[this.activeProfileId] || null; },
    hasPin: function () { return !!this.pin(); },
    setPin: function (p) { this._pin[this.activeProfileId] = p; save('w.pin', this._pin); },
    clearPin: function () { delete this._pin[this.activeProfileId]; save('w.pin', this._pin); },

    // ── Category prefs (per profile + playlist): manual hide / lock / order ──
    _cp: function () { var k = this._pk(); if (!this._cat[k]) this._cat[k] = { hidden: [], locked: [], order: {} }; return this._cat[k]; },
    hiddenCats: function () { return this._cp().hidden || []; },
    lockedCats: function () { return this._cp().locked || []; },
    isHidden: function (id) { return this.hiddenCats().indexOf(id) >= 0; },
    isLocked: function (id) { return this.lockedCats().indexOf(id) >= 0; },
    toggleHidden: function (id) { var c = this._cp(), i = c.hidden.indexOf(id); if (i >= 0) c.hidden.splice(i, 1); else c.hidden.push(id); save('w.cat', this._cat); },
    toggleLocked: function (id) { var c = this._cp(), i = c.locked.indexOf(id); if (i >= 0) c.locked.splice(i, 1); else c.locked.push(id); save('w.cat', this._cat); },
    catOrder: function (section) { var o = this._cp().order; return (o && o[section]) || []; },
    setCatOrder: function (section, ids) { var c = this._cp(); if (!c.order) c.order = {}; c.order[section] = ids; save('w.cat', this._cat); }
  };
  W.Store = Store;

  // ── Spatial D-pad navigation ──────────────────────────────────────────────────
  function visible(e) {
    if (e.offsetParent === null && e.getClientRects().length === 0) return false;
    var r = e.getBoundingClientRect();
    return r.width > 0 && r.height > 0;
  }
  var Nav = {
    scope: document,
    current: null,
    setScope: function (node) { this.scope = node || document; },
    list: function () {
      var all = this.scope.querySelectorAll('.focusable');
      var out = [];
      for (var i = 0; i < all.length; i++) if (visible(all[i])) out.push(all[i]);
      return out;
    },
    setFocus: function (e) {
      if (!e) return;
      if (this.current && this.current !== e) this.current.classList.remove('focused');
      this.current = e;
      e.classList.add('focused');
      try { e.scrollIntoView({ block: 'nearest', inline: 'nearest' }); } catch (x) { e.scrollIntoView(false); }
      if (typeof e._onFocus === 'function') e._onFocus(e);
    },
    focusFirst: function () {
      // Prefer an element explicitly marked autofocus, else the first.
      var f = this.list();
      if (!f.length) { this.current = null; return; }
      for (var i = 0; i < f.length; i++) if (f[i].hasAttribute('data-autofocus')) { this.setFocus(f[i]); return; }
      this.setFocus(f[0]);
    },
    activate: function () { if (this.current) this.current.click(); },
    move: function (dir) {
      if (!this.current || !visible(this.current)) { this.focusFirst(); return; }
      var r = this.current.getBoundingClientRect();
      var cx = r.left + r.width / 2, cy = r.top + r.height / 2;
      var best = null, bestScore = Infinity;
      var f = this.list();
      for (var i = 0; i < f.length; i++) {
        var c = f[i]; if (c === this.current) continue;
        var cr = c.getBoundingClientRect();
        var dx = (cr.left + cr.width / 2) - cx, dy = (cr.top + cr.height / 2) - cy;
        var primary, secondary;
        if (dir === 'left') { if (dx >= -2) continue; primary = -dx; secondary = Math.abs(dy); }
        else if (dir === 'right') { if (dx <= 2) continue; primary = dx; secondary = Math.abs(dy); }
        else if (dir === 'up') { if (dy >= -2) continue; primary = -dy; secondary = Math.abs(dx); }
        else { if (dy <= 2) continue; primary = dy; secondary = Math.abs(dx); }
        // Strongly prefer alignment on the perpendicular axis, then nearest.
        var score = primary + secondary * 3;
        if (score < bestScore) { bestScore = score; best = c; }
      }
      if (best) this.setFocus(best);
    }
  };
  W.Nav = Nav;

  // ── Router (screen stack; DOM kept on Back for instant return) ───────────────
  var appRoot = null;
  var Router = {
    stack: [],
    init: function (root) {
      appRoot = root;
      // webOS routes the remote Back button through history.back(). We keep the
      // history in sync with our screen stack: a state per screen, and popstate
      // pops one screen. This is why Back must NOT be handled in keydown.
      try { history.replaceState({ w: 0 }, ''); } catch (e) {}
      window.addEventListener('popstate', function () {
        if (Router.stack.length > 1) Router._pop();
        else if (W.onRootBack) W.onRootBack();
      });
    },
    push: function (node, opts) {
      opts = opts || {};
      if (this.stack.length) {
        var top = this.stack[this.stack.length - 1];
        top.focusEl = Nav.current;
        top.node.classList.add('hidden');
      }
      appRoot.appendChild(node);
      this.stack.push({ node: node, opts: opts });
      Nav.setScope(node);
      Nav.focusFirst();
      if (opts.onShow) opts.onShow(node);
      if (node._onShow) node._onShow(node);
      try { history.pushState({ w: this.stack.length }, ''); } catch (e) {}
    },
    replaceAll: function (node, opts) {
      while (this.stack.length) { this.stack.pop().node.remove(); }
      this.push(node, opts);
    },
    // Programmatic back → routes through history so it behaves like the remote.
    back: function () { try { history.back(); } catch (e) { this._pop(); } },
    // Actual screen pop (invoked by popstate, i.e. the Back button).
    _pop: function () {
      if (this.stack.length <= 1) { if (W.onRootBack) W.onRootBack(); return; }
      var top = this.stack.pop();
      if (top.opts.onBack) top.opts.onBack();
      top.node.remove();
      var cur = this.stack[this.stack.length - 1];
      cur.node.classList.remove('hidden');
      Nav.setScope(cur.node);
      if (cur.focusEl && document.contains(cur.focusEl) && visible(cur.focusEl)) Nav.setFocus(cur.focusEl);
      else Nav.focusFirst();
    },
    depth: function () { return this.stack.length; }
  };
  W.Router = Router;

  // ── Global key handling ──────────────────────────────────────────────────────
  // webOS: 461 = Back. Also support Esc(27), Backspace(8), Tizen(10009).
  function isTyping() {
    var a = document.activeElement;
    return a && (a.tagName === 'INPUT' || a.tagName === 'TEXTAREA');
  }
  document.addEventListener('keydown', function (e) {
    var k = e.keyCode;
    // Player (or any screen) can claim keys first.
    if (W.keyHook && W.keyHook(e, k) === true) { e.preventDefault(); return; }

    if (isTyping()) {
      // Let the on-screen keyboard handle typing; Back/OK leave the field.
      if (k === 461 || k === 27 || k === 13) { document.activeElement.blur(); e.preventDefault(); }
      return;
    }
    if (k === 37) { Nav.move('left'); e.preventDefault(); }
    else if (k === 38) { Nav.move('up'); e.preventDefault(); }
    else if (k === 39) { Nav.move('right'); e.preventDefault(); }
    else if (k === 40) { Nav.move('down'); e.preventDefault(); }
    else if (k === 13) { Nav.activate(); e.preventDefault(); }
    // NOTE: Back (461) is intentionally NOT handled here — webOS performs
    // history.back() on Back, which our popstate handler turns into a screen pop.
  });

  // ── Clock (topbar) ───────────────────────────────────────────────────────────
  W.startClock = function (node) {
    function tick() {
      if (!document.contains(node)) return;
      var d = new Date();
      var h = d.getHours(), m = d.getMinutes();
      node.textContent = (h < 10 ? '0' : '') + h + ':' + (m < 10 ? '0' : '') + m;
      setTimeout(tick, 15000);
    }
    tick();
  };
})();
