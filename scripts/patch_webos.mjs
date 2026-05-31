// ─────────────────────────────────────────────────────────────────────────────
// patch_webos.mjs — make a Flutter `build/web` output runnable on LG webOS.
//
// Run AFTER `flutter build web --release ...` and BEFORE `ares-package`:
//     node scripts/patch_webos.mjs
//
// webOS apps load from file:// on an OLD Chromium (webOS 6.x = Chrome 79). That
// breaks stock Flutter web; this script fixes it. It is RENDERER-AWARE:
//
//   • HTML renderer (Flutter ≤3.27, `--web-renderer html`) — DOM/CSS, no wasm.
//     This is what we ship to webOS (the α5-Gen4 TV can't drive CanvasKit). Only
//     needs: transpile loader to chrome79, base href "./", file:// fetch shim,
//     and the dead canvaskit/ assets removed.
//   • CanvasKit renderer (Flutter 3.29+) — kept for reference/other targets. Adds:
//     classic-iife canvaskit.js, force-local "full" variant, XHR-backed wasm.
//
// Common gotchas handled:
//   - Loader (flutter.js / flutter_bootstrap.js) uses ?./?? (Chrome 80+) → esbuild
//     transpile to chrome79.
//   - base href "/" → "./" (loaded from a file path, not web root).
//   - fetch() over file:// fails → XHR-backed fetch shim (assets, fonts, manifests).
//   - ⚠️ NEVER transpile main.dart.js: dart2js output has no ?./?? in executable
//     code, and running it through esbuild corrupts dart2js's runtime type system
//     (RTI) → every widget build throws "<type> is not a subtype" → grey screen.
//
// Robustness: every string replacement goes through `replaceOrThrow`, which FAILS
// the build loudly if its pattern isn't found (so a Flutter upgrade can't silently
// ship a broken IPK). Verified on Flutter 3.27.4 (html) and 3.44.0 (canvaskit).
// ─────────────────────────────────────────────────────────────────────────────
import { execSync } from 'node:child_process';
import { readFileSync, writeFileSync, existsSync, rmSync } from 'node:fs';
import { join } from 'node:path';

const WEB = join(process.cwd(), 'build', 'web');
const ESBUILD = 'npx -y esbuild@0.24.0';

if (!existsSync(WEB)) {
  console.error(`patch_webos: ${WEB} not found. Run "flutter build web --release" first.`);
  process.exit(1);
}

/** Replace exactly, asserting the pattern was present. Fails the build if not. */
function replaceOrThrow(src, pattern, replacement, label) {
  if (!pattern.test(src)) {
    throw new Error(
      `patch_webos: [${label}] pattern NOT found — Flutter's generated output ` +
      `likely changed. Re-derive this regex against build/web (see header). ` +
      `Pattern: ${pattern}`
    );
  }
  const out = src.replace(pattern, replacement);
  if (out === src) {
    throw new Error(`patch_webos: [${label}] replacement was a no-op.`);
  }
  console.log(`  ✓ [${label}] applied`);
  return out;
}

function esTranspile(rel) {
  const f = join(WEB, rel);
  if (!existsSync(f)) return;
  execSync(`${ESBUILD} "${f}" --target=chrome79 --allow-overwrite --outfile="${f}"`, { stdio: 'inherit' });
  console.log('  transpiled', rel);
}

// ── Detect renderer from the generated buildConfig ────────────────────────────
const bootstrapPath = join(WEB, 'flutter_bootstrap.js');
const bootstrapRaw = readFileSync(bootstrapPath, 'utf8');
const isHtmlRenderer = /"renderer"\s*:\s*"html"/.test(bootstrapRaw);
console.log(`patch_webos: renderer = ${isHtmlRenderer ? 'HTML (DOM)' : 'CanvasKit'}`);

// 1. Transpile the LOADER ONLY to chrome79 (never main.dart.js — see header).
for (const f of ['flutter.js', 'flutter_bootstrap.js']) esTranspile(f);

if (isHtmlRenderer) {
  // ── HTML build: no CanvasKit. Remove the dead canvaskit/ assets (~15 MB) so
  //    they don't bloat the IPK; the html renderer never loads them. ───────────
  const ckDir = join(WEB, 'canvaskit');
  if (existsSync(ckDir)) {
    rmSync(ckDir, { recursive: true, force: true });
    console.log('  ✓ removed unused canvaskit/ (HTML renderer)');
  }
} else {
  // ── CanvasKit build: classic-iife canvaskit.js + force-local + XHR wasm. ─────
  const ck = join(WEB, 'canvaskit', 'canvaskit.js');
  if (!existsSync(ck)) throw new Error(`patch_webos: ${ck} not found — CanvasKit renderer expected.`);
  execSync(`${ESBUILD} "${ck}" --bundle --format=iife --global-name=flutterCanvasKitInit --target=chrome79 --allow-overwrite --outfile="${ck}"`, { stdio: 'inherit' });
  console.log('  built classic canvaskit.js (global flutterCanvasKitInit)');
  const ckc = join(WEB, 'canvaskit', 'chromium', 'canvaskit.js');
  if (existsSync(ckc)) execSync(`${ESBUILD} "${ckc}" --target=chrome79 --allow-overwrite --outfile="${ckc}"`, { stdio: 'inherit' });

  let s = readFileSync(bootstrapPath, 'utf8');
  s = replaceOrThrow(
    s,
    /_flutter\.loader\.load\(\{\s*serviceWorkerSettings:/,
    '_flutter.loader.load({\n  config: { canvasKitBaseUrl: "canvaskit/", canvasKitVariant: "full" },\n  serviceWorkerSettings:',
    'force-local-canvaskit'
  );
  s = replaceOrThrow(
    s,
    /let e = WebAssembly\.compileStreaming\(fetch\(i\)\);\s*return \(n, t\) => \(\(async \(\) => \{\s*let r = await e, a = await WebAssembly\.instantiate\(r, n\);\s*t\(a, r\);\s*\}\)\(\), \{\}\);/,
    'return (n, t) => (window.fetch(i).then((R) => R.arrayBuffer()).then((buf) => WebAssembly.instantiate(buf, n)).then((res) => t(res.instance, res.module)), {});',
    'xhr-wasm-instantiate'
  );
  s = replaceOrThrow(
    s,
    /let l = k\(c\(s, "canvaskit\.wasm"\)\), u = await import\(o\);/,
    'let l = k(c(s, "canvaskit.wasm")), u = await new Promise((RES, REJ) => { if (window.flutterCanvasKitInit) { RES(window.flutterCanvasKitInit); return; } var SC = document.createElement("script"); SC.src = o; SC.onload = () => RES(window.flutterCanvasKitInit); SC.onerror = REJ; document.head.appendChild(SC); });',
    'classic-canvaskit-script'
  );
  writeFileSync(bootstrapPath, s);
  console.log('  patched flutter_bootstrap.js (local CK + classic-script + XHR wasm)');
}

// index.html: base href + file:// fetch shim (both renderers).
{
  const ip = join(WEB, 'index.html');
  let s = readFileSync(ip, 'utf8');
  s = replaceOrThrow(s, /<base href="\/">/, '<base href="./">', 'base-href');
  if (!s.includes('webOS file:// fetch shim')) {
    if (!s.includes('<body>')) {
      throw new Error('patch_webos: [fetch-shim] <body> anchor not found in index.html.');
    }
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
    console.log('  ✓ [fetch-shim] injected');
  } else {
    console.log('  • [fetch-shim] already present');
  }
  writeFileSync(ip, s);
  console.log('  patched index.html (base href ./ + fetch shim)');
}

console.log('patch_webos: done.');
