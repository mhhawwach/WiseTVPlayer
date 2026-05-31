# WiseVodPlayer — Samsung Tizen TV (native web app)

Same hand-built web app as the LG webOS build (`webos_native/`), packaged as a
Tizen **`.wgt`**. One codebase: `core.js` detects the platform (`W.platform`) and
adapts the Back key, exit API and colour-button registration.

- **Source:** shared `webos_native/{index.html,css,js}` + Tizen `tizen_native/config.xml` + `icon.png`.
- **Output:** `build/tizen/.buildResult/WiseVodPlayer.wgt`.
- Flutter is **not** used for Tizen anymore (too heavy for the TV GPU) — this replaces the old flutter-tizen `.tpk`.

## Build (Tizen Studio CLI already installed here)
```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_tizen.ps1 -SecProfile <yourProfile>
```
The script stages `build\tizen` from the shared app, then runs `tizen build-web`
+ `tizen package -t wgt`. Without a security profile it still produces an
**unsigned** `.wgt` (won't install on a retail TV).

## Signing (one-time, needs YOUR Samsung account)
A `.wgt` must be signed with an **author** certificate + a **distributor**
certificate. Create them in Tizen Studio → **Certificate Manager**:
1. **+ → Samsung → Create** (TV). Sign in with your Samsung account.
2. Author certificate: new (set a password) — **back up the `.p12`**, it can't be regenerated.
3. Distributor certificate:
   - **Partner/Public** for the Samsung **Seller Office** store, or
   - add your TV's **DUID** for sideload testing (Device Manager shows the DUID).
4. This creates a **security profile** (e.g. `WiseVod`). Build with it:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\build_tizen.ps1 -SecProfile WiseVod
   ```

## Test on your Samsung TV (Developer Mode)
1. TV: **Apps → 1 2 3 4 5 → Developer Mode ON**, enter this PC's IP, reboot the TV.
2. Connect + install:
   ```powershell
   & "$env:USERPROFILE\tizen-studio\tools\sdb.exe" connect <TV-IP>
   tizen install -n WiseVodPlayer.wgt -t <deviceId> --   # or use Tizen Studio: Run As > Tizen Web Application
   ```
   (Tizen Studio GUI: **File → Import → Tizen Project →** `build\tizen`, then **Run As → Tizen Web Application**.)

## Store note
For the **Samsung Seller Office** (store), use a **Public** distributor
certificate and delete `js/seed.js` from the staged build first (it bakes in the
test playlist credentials — fine for your own TV, never for the store).
