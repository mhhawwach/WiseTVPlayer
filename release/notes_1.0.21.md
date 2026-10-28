## WiseVodPlayer v1.0.21 — QA fixes

> **Android / Fire TV: one-time reinstall.** This version is signed with a new,
> permanent release key, so it can't install over v1.0.20 or older. Uninstall
> the old WiseVodPlayer first, then install this one (playlists, favourites and
> history start fresh). From now on, updates install in-app.

Everything found in the 2026-10-26 QA pass.

### Remote / D-pad
- **Parental PIN can now be set with a remote.** The Set PIN page's number pad
  takes D-pad focus (starting on 5) and remotes with number keys type directly.
- **No more dead ends on empty pages.** Opening an empty tab (e.g. Favourites)
  keeps the highlight on the side menu instead of losing it.
- **Search boxes no longer grab the remote.** Live TV and Search use the app's
  own TV keyboard (OK to type, results update live); the arrows always move on.
- **Every button shows focus on TV.** Standard buttons (Add Playlist, "+",
  Save/Cancel, Back arrows, dialogs) now get a bright focus ring.
- **Arabic layout:** the arrows to and from the side menu follow the
  right-to-left layout.
- **Left goes to the menu** instead of jumping up the page (episode lists,
  Settings rows).
- **On-screen keyboard moves predictably** row by row (Left/Right stay on the
  row, Up/Down pick the key directly above/below).
- Focus lands on the new playlist after adding one, and on the first season
  when a series opens.

### Back button (Android 13+)
- **Back no longer closes the app by surprise.** From a tab it returns to Home;
  on Home it asks "Press Back again" then "Exit?".
- **Back from the player returns to the page you came from** (it skipped the
  details page), and Back from a movie/series page returns to the grid or
  search results.

### Playback
- **No more endless black screen.** If a stream won't start or stops, you get
  "Couldn't play — Retry / Back" (Retry resumes where you were).
- **Live TV reconnects by itself** when a channel freezes, before giving up.
- The Live TV preview shows "No signal" instead of staying black.

### Loading
- A garbled or cut-off catalogue download is retried automatically, and Home
  shows "Couldn't load — Retry" instead of an empty page.
- Load errors are shown as short messages (they used to print the raw error,
  which could include the playlist login).
- Choosing a profile shows a spinner while its data loads.

### Updates
- **In-app updates now work.** The app checks the latest GitHub release.
  Android TV / Fire TV download and install the new APK in-app (Android asks
  once to allow installs from this app); Windows downloads and runs the
  installer.

### Looks
- Series pages show their backdrop image again (it was always blank).
- "1200 min / ep" style runtimes are converted or hidden.
- The Home banner stops rotating while you point at it.
- Theme changes apply everywhere immediately.
- Phones: the header no longer overlaps posters; the side menu fits the screen.
- Focused full-width rows no longer spill past the screen edge; the selected
  language/text-size pill is readable when focused.
- Clearer Favourites hint; screen-reader labels on icon-only keys.
