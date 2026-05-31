/* api.js — Xtream Codes client (fetch-based, in-memory cached). */
(function () {
  'use strict';
  var W = window.W;
  function base(pl) { return pl.url.replace(/\/+$/, ''); }
  function enc(s) { return encodeURIComponent(s); }

  function fetchJSON(url, ms) {
    var ctl = window.AbortController ? new AbortController() : null;
    var to = ctl ? setTimeout(function () { ctl.abort(); }, ms || 60000) : null;
    return fetch(url, ctl ? { signal: ctl.signal } : {}).then(function (r) {
      if (to) clearTimeout(to);
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    });
  }
  function api(pl, params) {
    var q = 'username=' + enc(pl.user) + '&password=' + enc(pl.pass);
    for (var k in params) { if (params.hasOwnProperty(k) && params[k] != null) q += '&' + k + '=' + enc(params[k]); }
    return fetchJSON(base(pl) + '/player_api.php?' + q);
  }

  var cache = {};
  function memo(key, fn) {
    if (cache[key]) return Promise.resolve(cache[key]);
    return fn().then(function (v) { cache[key] = v; return v; });
  }

  W.Api = {
    clearCache: function () { cache = {}; },
    auth: function (pl) { return api(pl, {}); },

    liveCats: function (pl) { return memo('lc:' + pl.id, function () { return api(pl, { action: 'get_live_categories' }); }); },
    liveStreams: function (pl, cat) { return memo('ls:' + pl.id + ':' + (cat || 'all'), function () { var p = { action: 'get_live_streams' }; if (cat) p.category_id = cat; return api(pl, p); }); },
    vodCats: function (pl) { return memo('vc:' + pl.id, function () { return api(pl, { action: 'get_vod_categories' }); }); },
    vodStreams: function (pl, cat) { return memo('vs:' + pl.id + ':' + (cat || 'all'), function () { var p = { action: 'get_vod_streams' }; if (cat) p.category_id = cat; return api(pl, p); }); },
    seriesCats: function (pl) { return memo('sc:' + pl.id, function () { return api(pl, { action: 'get_series_categories' }); }); },
    series: function (pl, cat) { return memo('ss:' + pl.id + ':' + (cat || 'all'), function () { var p = { action: 'get_series' }; if (cat) p.category_id = cat; return api(pl, p); }); },
    vodInfo: function (pl, id) { return api(pl, { action: 'get_vod_info', vod_id: id }); },
    seriesInfo: function (pl, id) { return api(pl, { action: 'get_series_info', series_id: id }); },

    liveUrlTs: function (pl, id) { return base(pl) + '/live/' + enc(pl.user) + '/' + enc(pl.pass) + '/' + id + '.ts'; },
    liveUrlHls: function (pl, id) { return base(pl) + '/live/' + enc(pl.user) + '/' + enc(pl.pass) + '/' + id + '.m3u8'; },
    vodUrl: function (pl, id, ext) { return base(pl) + '/movie/' + enc(pl.user) + '/' + enc(pl.pass) + '/' + id + '.' + (ext || 'mp4'); },
    epUrl: function (pl, id, ext) { return base(pl) + '/series/' + enc(pl.user) + '/' + enc(pl.pass) + '/' + id + '.' + (ext || 'mp4'); }
  };
})();
