## WiseVodPlayer v1.0.20 — Navigation & Focus overhaul

A single theme this release: **the D-pad / keyboard can no longer lose you.**

### The big one (Fire TV / Android TV)
- **On-screen keyboard focus black-hole fixed** — an invisible, sheet-sized
  focus wrapper could capture the highlight (typically around the middle of
  the QWERTY row, e.g. the **T** key). Once on it, no arrow key could ever
  escape and the highlight was gone for good. The wrapper no longer takes
  focus.

### Popups & dialogs
- **Bottom sheets no longer leak focus behind themselves** — pressing ← inside
  a sheet (profile actions, EPG, catch-up, category options, TV keyboard) used
  to silently move the highlight to the side rail *behind* the open sheet,
  making the popup feel dead / impossible to close.
- **Focus recovery is now modal-aware** — when a popup opens, the TV focus
  watchdog heals focus *into* the popup instead of re-focusing the page behind
  the barrier.
- **Update dialog** gets initial remote focus on "Update Now".
- **Parental PIN pad is now D-pad navigable** (its keys previously couldn't
  take focus at all — the dialog was unusable with a remote). Digit keys on a
  remote/keyboard also type the PIN directly.
- **EPG panel entries are focusable** — arrowing through them scrolls the
  guide, so entries below the fold are reachable by remote.

### Search & text fields
- **Global Search no longer traps the D-pad** — ↑/↓ escape the search box to
  reach results / the rail.
- **← in a text box moves the cursor again** (desktop/keyboard) instead of
  jumping focus to the side rail mid-typing.
- **Add Playlist works with the remote** — arrows now move between the four
  fields and the Connect & Save button (fields used to swallow every arrow).
- The app resolves its TV/phone profile before the first frame (no more
  editable-field flash + system-IME pop on TVs when opening Add Playlist).

### Side rail & tabs
- **Rail highlight no longer teleports** when activating a tab (each tab now
  keeps its own stable focus node).
- **→ from the rail lands on the top-left item** of the page instead of a
  random one (sometimes the refresh button or a mid-page card).
- Slow-loading Live TV no longer yanks focus away if you've started typing in
  a search box meanwhile.

### Keyboard consistency (desktop + TV)
- **Space and NumPad-Enter** now activate cards, rail items, player controls,
  profile options and channel tiles (previously only plain Enter/OK worked).
- **Held-down arrows** behave like repeated presses everywhere (detail-page
  scrolling, field escape, rail bridging) instead of switching behaviour
  mid-hold.

### Downloads
- **WiseTVPlayer.apk** — Android / Android TV / Fire TV
- **WiseVodPlayer-Setup-1.0.20.exe** — Windows 10 / 11
- **WiseVodPlayer-LG-webOS.ipk** — LG webOS native app (v2.0.1, unchanged)
