# Content-language filter ("Customize your experience")

Per-profile, per-playlist language interest filter. Ships in the one Flutter
codebase → **mobile, Android TV, webOS, and Windows** all at once.

## What the user sees
- On the **first launch of each profile** (once an active playlist exists), a
  popup — *"Let's customize your experience"* — lists the languages **detected
  in that playlist** as checkboxes. **Arabic + English are pre-checked.**
- Their choice is applied across **Live TV, Movies, Series**, the **Home** rows
  (hero / recently added / top rated / popular series) and **global search**.
- Re-openable anytime: **Settings → Content languages**.
- Stored per **(profile, playlist)** — each profile and each playlist keeps its
  own selection.

## The rule (decided with the user)
A category is shown when its name's detected language is **selected**, OR it has
**no language marker** (genres like Drama/Comedy/News/Sports → always shown).
Only language-tagged categories in *unselected* languages are hidden.

### Detection — `lib/core/language/category_language.dart`
"Smart" matching, case-insensitive, in priority order:
1. **Arabic script** anywhere → Arabic.
2. **Full words**: language names (`English`, `Turkish`…), countries/regions
   (`Lebanon`,`Palestine`,`Egypt`… → Arabic; `UK`,`USA` → English; `Iran` →
   Persian; `Korea` → Korean; `India`/`Hindi` → Indian; …), and content markers
   (`Quran`,`Ramadan` → Arabic).
3. **2-letter codes** at word boundaries only (`EN`,`AR`,`FR`,`ES`,`IT`,`TR`,
   `US`,`UK`…). Collision-prone codes `de` / `in` / `au` are **excluded** (they
   are common words — "Filmes **de** Terror", "Movies **in** HD", "Films **au**
   Cinéma"); their full words still match. Boundaries stop `ar`/`us`/`es` firing
   inside "war"/"music"/"series".

No match → `null` → **always shown**.

`languagesPresent(categories)` powers the auto-detect popup list.
Default selection = Arabic+English where present, else everything (so a playlist
with neither never starts out hiding all its tagged content).

### Real WiseVOD playlist (validated by `test/category_language_test.dart`)
- **Hidden by default** (until the user opts in): `Turkish Series`,
  `Korean Series`, `Indian Series`, `Iranian series`.
- **Always shown**: Arabic (`Arabic`, `Arabic Series`, `Lebanon TV`,
  `Palestine TV`, `The Holy Quran`, `Ramadan 2026`), `English Series`, and every
  genre (`Drama`, `Comedy`, `Documentary`, `News`, `Sports`, `Action and
  Thriller`, `Kids and anime`, `NEW`, …).

## Architecture
- `core/language/category_language.dart` — pure classifier + helpers (unit-tested).
- `core/language/language_prefs.dart` — `languagePrefsProvider` (the stored
  selection) + pure `blockedCategoryIdsFor(cats, selection)` / `effectiveSelection`.
  Core-only deps, so feature screens import it without an import cycle.
- `core/storage/storage_service.dart` — `selectedLanguages` / `setSelectedLanguages`
  / `languagePrefsSeen` keyed `${profileId}_lang_sel_${playlistId}`.
- `features/onboarding/language_prefs_dialog.dart` — the popup, the
  `LanguagePrefsGate` (first-launch trigger, mounted invisibly on Home), and
  `openLanguagePrefsForActivePlaylist` (the Settings re-entry).

### How filtering reaches each surface
Each consumer watches `languagePrefsProvider` + the relevant category list and
computes the blocked-id set client-side (no network, no provider invalidation —
saving the popup re-renders everything that watches the provider):
- **Category grids** — `applyOrderAndFilter(..., langBlocked:)` in `category_grid.dart`.
- **Home rows** — `home_screen.dart` filters the catalogue via the vod/series category maps.
- **All-content lists** — `_process(..., langBlocked)` in movies/series list screens
  (no-op inside a single already-allowed category; active in the "All" view).
- **Search** — `search_screen.dart` filters live/vod/series results by category.
- **Reloads** — `content_refresh.invalidateAllContent` (playlist switch) and the
  profile-switch sites call `languagePrefsProvider.notifier.reload()`.

## Notes
- **Continue Watching** is intentionally **not** filtered — it's the user's own
  history (and carries no category id).
- The "All Channels/Movies/Series" synthetic card is never hidden; it shows the
  allowed set.
- Verified: `flutter analyze` clean (no new issues), 49/49 unit tests pass,
  `flutter build windows --release` succeeds.
