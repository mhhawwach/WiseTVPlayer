# D-pad Focus Audit & Hardening — change log

Goal: stop the TV focus highlight from "fading away / needing many presses to
get back". Each change below is a **separate git commit** so it can be reverted
independently (`git revert <sha>` or `git checkout <sha>~1 -- <file>`).

Branch: `platform/smart-tv`. Baseline before this work: `ddb7ebb`
(feat(tv): global Live TV search, brighter focus highlight, reachable Settings).

## Findings

| # | Issue | Where | Why it loses focus |
|---|-------|-------|--------------------|
| F1 | No global focus recovery | whole app | When the focused widget is disposed (list recycle, content refresh, async rebuild, tab switch) focus drops to a `FocusScopeNode`; D-pad presses are then absorbed re-entering a scope → "highlight gone, press many times". |
| F2 | No `cacheExtent` on focusable lists/grids | home rows, movies/series grids, live channels, search, favourites, recently-watched | Off-screen focused item gets disposed → focus lost. |
| F3 | Rail focus highlight uses old purple `AppColors.primary` | `home_shell.dart` (`_TVRailItem`, `_ProfileRailButton`) | Inconsistent with the new bright cyan focus; less visible. |
| F4 | `_focusContent()` no-ops while content loads | `home_shell.dart` | Pressing Right during initial load does nothing (not a loss, but feels like one). |

## Changes — each is its own commit (revert independently)

- **[F1] Global focus-recovery watchdog.** New `lib/core/widgets/focus_recovery.dart`,
  wrapped around the app in `lib/app.dart`. TV-only: tracks the last concrete
  focused node; if focus drops to a scope/null and is still lost after a frame,
  restores it to that node (if alive) else the first focusable in the scope.
  *Revert:* remove the `FocusRecovery(...)` wrap in `app.dart` + delete the file.

- **[F2] Keep the focused item alive in lazy lists.** `FocusableCard` and the
  Live-TV `_CategoryRailItem` now use `AutomaticKeepAliveClientMixin` with
  `wantKeepAlive => _focused`. The focused card/category is never disposed by a
  `ListView/GridView.builder` recycling it off-screen, which was the main loss
  cause. Files: `lib/core/widgets/focusable_card.dart`,
  `lib/features/live_tv/live_channels_screen.dart`.
  *Revert:* drop the mixin + `wantKeepAlive` + `super.build` + `updateKeepAlive()`.

- **[F3] Rail focus highlight → bright cyan.** `_TVRailItem` and
  `_ProfileRailButton` in `lib/features/home/home_shell.dart` now use
  `AppColors.focus` (was `AppColors.primary`), matching the rest of the app and
  more visible. *Revert:* swap `AppColors.focus` back to `AppColors.primary`.

- **[F4] `_focusContent` retry.** `home_shell.dart` retries focusing the content
  once after the frame if the page is still loading, so Right reliably enters
  content. *Revert:* restore the single-shot loop.

## Round 2 — driven by an independent audit pass

- **[F5] Profiles screen autofocus conflict.** `profiles_screen.dart` set
  `autofocus: !isActive` on every non-active `_ProfileCard`, so 2+ non-active
  profiles meant multiple `autofocus:true` in one scope → initial highlight
  landed unpredictably / looked missing. Now a single card (index 0)
  autofocuses. *Revert:* restore `autofocus: !isActive`.
- **[F6] "Continue Watching" / "Recently Watched" reachable.**
  `recently_watched_row.dart` `_HistoryCard` was a bare `GestureDetector`
  (unreachable by D-pad). Now a `FocusableCard` (also gets keep-alive + cyan
  focus). *Revert:* swap back to `GestureDetector`.
- **[F7] Track picker seeds focus.** `track_picker_sheet.dart` autofocuses the
  selected (or first) audio/subtitle track so the sheet opens highlighted.
- **[F8] Watchdog activation hardened.** `focus_recovery.dart` now activates on
  `isTV` **OR** the first D-pad/remote key, so it still works on boxes where the
  native leanback `isTV` check returns false (and stays inert on touch phones).

### Considered but NOT done (covered by the F1 watchdog, or separate features)
- Broad `cacheExtent` on every list/grid — skipped to avoid extra image-decode
  memory on the 2 GB TCL. F2 (keep-alive of just the focused item) achieves the
  goal far more surgically; F1 catches the rest.
- Per-item keep-alive on the Catch-Up sheet, Playlists list, and Category
  Manager (lazy lists with custom focusables): focus LOSS there is recovered by
  the F1 watchdog; not seamless-stay-in-place, but no "press many times".
- **PIN num-pad not D-pad focusable** (`pin_dialog.dart`, `pin_setup_screen.dart`)
  — a real defect (can't enter a parental PIN by remote), but it's a separate
  reachability feature, not the "fade" symptom. Flagged for a follow-up.
- Home hero Play / More-Info aren't individually focusable (the whole hero card
  is the focus target) — acceptable; the hero card works.
