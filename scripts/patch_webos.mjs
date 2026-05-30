// ─────────────────────────────────────────────────────────────────────────────
// patch_webos.mjs — make a Flutter `build/web` output runnable on LG webOS.
//
// Run AFTER `flutter build web --release` and BEFORE `ares-package`:
//     node scripts/patch_webos.mjs
//
// webOS apps load from file:// on an OLD Chromium (webOS 6.x = Chrome 79).
// That breaks stock Flutter web in several ways; this script fixes each:
//
//   1. SYNTAX: Flutter's loader + CanvasKit use ?. / ?? (Chrome 80+).
//      → transpile all JS to chrome79 with esbuild.
//   2. base href "/" → "./"  (app is loaded from a file path, not web root).
//   3. ES-MODULE IMPORT over file:// is blocked → CanvasKit is loaded via
//      dynamic import(). Rebuild canvaskit.js as a CLASSIC iife exposing a
//      global, and patch the loader to inject it with <script> instead.
//   4. fetch() over file:// fails → inject an XHR-backed fetch shim
//      (for assets, manifests, fonts) and load the wasm via that shim.
//   5. Force LOCAL CanvasKit (default pulls it from the gstatic CDN).
//
// KNOWN REMAINING ISSUE: cold start is ~21s on a 2021 webOS TV (CanvasKit
// wasm compile + 4MB main.dart.js parse). It DOES reach first frame
// (diagnostics showed flutter-view attached at t+21s) but that's too slow to
// ship. Next: cache the compiled wasm / trim startup. The HTML renderer would
// avoid CanvasKit entirely but was removed in Flutter 3.29+ (we're on 3.44),
// so the fallback plan is a separate web build on Flutter <=3.27 with
// `--web-renderer html`.
// ─────────────────────────────────────────────────────────────────────────────
import { execSync } from 'node:child_process';
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const WEB = join(process.cwd(), 'build', 'web');
const ESBUILD = 'npx -y esbuild@0.24.0';

function esTranspile(rel) {
  const f = join(WEB, rel);
  if (!existsSync(f)) return;
  execSync(`${ESBUILD} "${f}" --target=chrome79 --allow-overwrite --outfile="${f}"`, { stdio: 'inherit' });
  console.log('  transpiled', rel);
}

// 1. Transpile loader + app JS to chrome79.
for (const f of ['flutter.js', 'flutter_bootstrap.js', 'main.dart.js']) esTranspile(f);

// 3. Build CLASSIC (iife global) CanvasKit from the ESM module.
{
  const ck = join(WEB, 'canvaskit', 'canvaskit.js');
  if (existsSync(ck)) {
    // bundle the ESM into a global `flutterCanvasKitInit` ({ default: CanvasKitInit }).
    execSync(`${ESBUILD} "${ck}" --bundle --format=iife --global-name=flutterCanvasKitInit --target=chrome79 --allow-overwrite --outfile="${ck}"`, { stdio: 'inherit' });
    console.log('  built classic canvaskit.js (global flutterCanvasKitInit)');
  }
  // chromium variant isn't used on Chrome 79 (needs Intl.Segmenter) but transpile defensively.
  const ckc = join(WEB, 'canvaskit', 'chromium', 'canvaskit.js');
  if (existsSync(ckc)) execSync(`${ESBUILD} "${ckc}" --target=chrome79 --allow-overwrite --outfile="${ckc}"`, { stdio: 'inherit' });
}

// 5 + 3 + 4: patch flutter_bootstrap.js (force local CK, classic-script load, XHR wasm).
{
  const bp = join(WEB, 'flutter_bootstrap.js');
  let s = readFileSync(bp, 'utf8');

  // 5. Force local CanvasKit (else it loads from the gstatic CDN, untranspiled).
  s = s.replace(
    /_flutter\.loader\.load\(\{\s*serviceWorkerSettings:/,
    '_flutter.loader.load({\n  config: { canvasKitBaseUrl: "canvaskit/" },\n  serviceWorkerSettings:'
  );

  // 4. wasm via (shimmed) fetch -> arrayBuffer -> instantiate (no compileStreaming).
  s = s.replace(
    /let e = WebAssembly\.compileStreaming\(fetch\(i\)\);\s*return \(n, t\) => \(\(async \(\) => \{\s*let r = await e, a = await WebAssembly\.instantiate\(r, n\);\s*t\(a, r\);\s*\}\)\(\), \{\}\);/,
    'return (n, t) => (window.fetch(i).then((R) => R.arrayBuffer()).then((buf) => WebAssembly.instantiate(buf, n)).then((res) => t(res.instance, res.module)), {});'
  );

  // 3. CanvasKit via classic <script> + global instead of dynamic import().
  s = s.replace(
    /let l = k\(c\(s, "canvaskit\.wasm"\)\), u = await import\(o\);/,
    'let l = k(c(s, "canvaskit.wasm")), u = await new Promise((RES, REJ) => { if (window.flutterCanvasKitInit) { RES(window.flutterCanvasKitInit); return; } var SC = document.createElement("script"); SC.src = o; SC.onload = () => RES(window.flutterCanvasKitInit); SC.onerror = REJ; document.head.appendChild(SC); });'
  );

  writeFileSync(bp, s);
  console.log('  patched flutter_bootstrap.js (local CK + classic-script + XHR wasm)');
}

// 2 + 4: index.html base href + fetch shim.
{
  const ip = join(WEB, 'index.html');
  let s = readFileSync(ip, 'utf8');
  s = s.replace('<base href="/">', '<base href="./">');
  if (!s.includes('webOS file:// fetch shim')) {
    const shim = `  <!-- webOS file:// fetch shim (XHR-backed) -->
  <script>
    (function () {
      var origFetch = window.fetch ? window.fetch.bind(window) : null;
      function guessType(u) {
        if (/\\.wasm(\\?|#|$)/i.test(u)) return 'application/wasm';
        if (/\\.m?js(\\?|#|$)/i.test(u)) return 'text/javascript';
        if (/\\.json(\\?|#|$)/i.test(u)) return 'application/json';
        if (/\\.(png|jpg|jpeg|webp|gif|bmp)(\\?|#|$)/i.test(u)) return 'image/png';
        if (/\\.(otf|ttf|woff2?)(\\?|#|$)/i.test(u)) return 'font/ttf';
        return 'application/octet-stream';
      }
      window.fetch = function (input, init) {
        var url = (typeof input === 'string') ? input : (input && input.url) || String(input);
        if (/^(https?:|data:|blob:)/i.test(url) && origFetch) return origFetch(input, init);
        return new Promise(function (resolve, reject) {
          try {
            var xhr = new XMLHttpRequest();
            xhr.open('GET', url, true);
            xhr.responseType = 'arraybuffer';
            xhr.onload = function () {
              var resp = new Response(xhr.response, { status: 200, headers: { 'Content-Type': guessType(url) } });
              try { Object.defineProperty(resp, 'url', { value: url }); } catch (e) {}
              resolve(resp);
            };
            xhr.onerror = function () { reject(new TypeError('XHR failed: ' + url)); };
            xhr.send();
          } catch (e) { reject(e); }
        });
      };
    })();
  </script>
`;
    s = s.replace('<body>', '<body>\n' + shim);
  }
  writeFileSync(ip, s);
  console.log('  patched index.html (base href ./ + fetch shim)');
}

console.log('patch_webos: done.');
