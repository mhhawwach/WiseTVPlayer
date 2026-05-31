/* app.js — bootstrap. Picks the first screen and hides the boot splash. */
(function () {
  'use strict';
  var W = window.W;
  function start() {
    W.Router.init(document.getElementById('app'));
    // At the root, Back exits the app (webOS) instead of doing nothing.
    W.onRootBack = function () {
      try {
        if (W.platform === 'tizen' && window.tizen && window.tizen.application) {
          window.tizen.application.getCurrentApplication().exit();
        } else if (window.webOS && window.webOS.platformBack) {
          window.webOS.platformBack();
        } else { window.close(); }
      } catch (e) {}
    };
    W.Store.ensureProfile();
    if (!W.Store.active() && W.SEED) { W.Store.addPlaylist(W.SEED); W.Api.clearCache(); }
    if (!W.Store.active()) W.Router.replaceAll(W.Screens.login());
    else if (W.Store.profiles.length > 1) W.Router.replaceAll(W.More.profileSelect());
    else W.Router.replaceAll(W.Screens.home());

    var boot = document.getElementById('boot');
    if (boot) { boot.classList.add('hide'); setTimeout(function () { boot.style.display = 'none'; }, 300); }
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
