/* player.js — full-screen video.
   - VOD: native <video> (TV hardware decoder). Live: native HLS first, mpegts.js
     (.ts) fallback on error.
   - Resume: seeks to the saved position; saves progress every 10s + on exit.
   - Colour buttons: Blue=aspect, Yellow=audio track, Green=subtitle track.
   - Back is handled by the global popstate→Router._pop (which runs cleanup). */
(function () {
  'use strict';
  var W = window.W, el = W.el, Router = W.Router, Store = W.Store, Api = W.Api, toast = W.toast;

  var mp = null, video = null, hideT = null, ctl = null, isLive = false, triedMpegts = false, saveT = null;
  var ASPECTS = ['contain', 'cover', 'fill'], aspectIdx = 0;

  function open(opts) {
    var pl = Store.active(); if (!pl) return;
    isLive = !!opts.live; triedMpegts = false; aspectIdx = 0;
    var H = opts.hist;
    function vodLike() { return H && H.type !== 'live'; }

    video = el('video', { autoplay: 'autoplay', preload: 'auto', playsinline: 'playsinline' });
    var bar = el('i');
    var spin = el('div', { class: 'spinner spin' });
    var title = el('div', { class: 'title', text: opts.title || '' });
    var status = el('div', { class: 'sub', style: { color: '#A6A6B8', fontSize: '18px', marginTop: '8px' } });
    var hint = el('div', { class: 'phint', text: (isLive ? 'OK Pause' : 'OK Pause   ◀ ▶ Seek') + '   🔵 Aspect   🟡 Audio   🟢 Subtitle' });
    ctl = el('div', { class: 'ctl' }, [title, isLive ? null : el('div', { class: 'bar' }, bar), status, hint]);
    var screen = el('div', { class: 'screen player' }, [video, spin, ctl]);

    function showCtl() { ctl.classList.remove('hide'); if (hideT) clearTimeout(hideT); hideT = setTimeout(function () { ctl.classList.add('hide'); }, 3500); }

    video.addEventListener('waiting', function () { spin.style.display = ''; });
    video.addEventListener('playing', function () { spin.style.display = 'none'; });
    video.addEventListener('canplay', function () { spin.style.display = 'none'; });
    video.addEventListener('error', onError);
    if (!isLive) video.addEventListener('timeupdate', function () { if (video.duration) bar.style.width = (video.currentTime / video.duration * 100) + '%'; });

    // Resume to the saved position once metadata is known.
    video.addEventListener('loadedmetadata', function () {
      if (vodLike() && !opts.fromStart) {
        var r = Store.getResume(H.type, H.id);
        if (r > 3 && (!video.duration || r < video.duration - 5)) { try { video.currentTime = r; } catch (e) {} }
      }
    });

    function startNative(src) { try { if (mp) { mp.destroy(); mp = null; } } catch (e) {} video.src = src; var p = video.play(); if (p && p.catch) p.catch(function () {}); }
    function startMpegts(src) {
      triedMpegts = true;
      try {
        if (mp) { mp.destroy(); mp = null; }
        video.removeAttribute('src');
        mp = window.mpegts.createPlayer({ type: 'mpegts', isLive: true, url: src }, { liveBufferLatencyChasing: true });
        mp.attachMediaElement(video); mp.load();
        var p = video.play(); if (p && p.catch) p.catch(function () {});
      } catch (e) {}
    }
    function onError() {
      if (isLive && !triedMpegts && window.mpegts && window.mpegts.isSupported && window.mpegts.isSupported()) {
        startMpegts(opts.srcTs);
      } else {
        var c = video && video.error ? video.error.code : '?';
        status.textContent = 'Playback error (code ' + c + '). Stream may be offline or use an unsupported codec.';
        spin.style.display = 'none';
      }
    }

    if (isLive) startNative(opts.srcHls); else startNative(opts.src);

    // History: record the open + save progress periodically.
    if (vodLike()) {
      Store.saveHist({ type: H.type, id: H.id, name: H.name, icon: H.icon, ext: H.ext, seriesName: H.seriesName, epNum: H.epNum, position: opts.fromStart ? 0 : Store.getResume(H.type, H.id), duration: 0 });
      saveT = setInterval(function () { if (video && video.duration && !video.paused) Store.setPosition(H.type, H.id, video.currentTime, video.duration); }, 10000);
    }

    function cycleAspect() { aspectIdx = (aspectIdx + 1) % ASPECTS.length; video.style.objectFit = ASPECTS[aspectIdx]; toast('Aspect: ' + ASPECTS[aspectIdx]); }
    function cycleAudio() {
      var t = video.audioTracks;
      if (!t || t.length < 2) { toast('No alternate audio track'); return; }
      var cur = 0; for (var i = 0; i < t.length; i++) if (t[i].enabled) cur = i;
      var nx = (cur + 1) % t.length;
      for (var j = 0; j < t.length; j++) t[j].enabled = (j === nx);
      toast('Audio: ' + (t[nx].language || t[nx].label || ('Track ' + (nx + 1))));
    }
    function cycleSub() {
      var t = video.textTracks;
      if (!t || t.length === 0) { toast('No subtitles available'); return; }
      var cur = -1; for (var i = 0; i < t.length; i++) if (t[i].mode === 'showing') cur = i;
      for (var j = 0; j < t.length; j++) t[j].mode = 'disabled';
      var nx = cur + 1;
      if (nx >= t.length) { toast('Subtitles: Off'); return; }
      t[nx].mode = 'showing'; toast('Subtitles: ' + (t[nx].language || t[nx].label || ('Track ' + (nx + 1))));
    }

    function cleanup() {
      if (hideT) clearTimeout(hideT); if (saveT) clearInterval(saveT);
      if (vodLike() && video && video.duration) Store.setPosition(H.type, H.id, video.currentTime, video.duration);
      document.documentElement.classList.remove('playing');
      document.body.classList.remove('playing');
      W.keyHook = null;
      try { if (mp) { mp.destroy(); mp = null; } } catch (e) {}
      try { video.pause(); video.removeAttribute('src'); video.load(); } catch (e) {}
      video = null; ctl = null;
    }

    // Owns the remote while playing. Back is NOT here — webOS Back → history.back
    // → popstate → Router._pop → onBack(cleanup).
    W.keyHook = function (e, k) {
      showCtl();
      if (k === 13) { if (video.paused) video.play(); else video.pause(); return true; }
      if (!isLive && (k === 39 || k === 37)) { var d = k === 39 ? 15 : -15; try { video.currentTime = Math.max(0, video.currentTime + d); } catch (x) {} return true; }
      if (k === 406) { cycleAspect(); return true; }       // Blue
      if (k === 405) { cycleAudio(); return true; }         // Yellow
      if (k === 404) { cycleSub(); return true; }           // Green
      if (k === 38 || k === 40 || k === 37 || k === 39) return true;
      return false;
    };

    document.documentElement.classList.add('playing');
    document.body.classList.add('playing');
    Router.push(screen, { onBack: cleanup });
    showCtl();
  }

  W.Player = {
    openLive: function (it) {
      open({ title: it.name, srcHls: Api.liveUrlHls(Store.active(), it.stream_id), srcTs: Api.liveUrlTs(Store.active(), it.stream_id), live: true,
        hist: { type: 'live', id: it.stream_id, name: it.name, icon: it.stream_icon } });
    },
    openVod: function (it, fromStart) {
      open({ title: it.name, src: Api.vodUrl(Store.active(), it.stream_id, it.container_extension), live: false, fromStart: !!fromStart,
        hist: { type: 'vod', id: it.stream_id, name: it.name, icon: it.stream_icon, ext: it.container_extension } });
    },
    openEpisode: function (s, ep, fromStart) {
      open({ title: (s.name || '') + '  ·  E' + (ep.episode_num || ''), src: Api.epUrl(Store.active(), ep.id, ep.container_extension), live: false, fromStart: !!fromStart,
        hist: { type: 'series', id: ep.id, name: (s.name || '') + ' · E' + (ep.episode_num || ''), icon: s.cover, ext: ep.container_extension, seriesName: s.name, epNum: ep.episode_num } });
    }
  };
})();
