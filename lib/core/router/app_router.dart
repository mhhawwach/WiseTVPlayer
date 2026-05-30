import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/vod_stream.dart';
import '../../data/models/series_stream.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/live_tv/live_channels_screen.dart';
import '../../features/movies/movies_categories_screen.dart';
import '../../features/movies/movies_list_screen.dart';
import '../../features/movies/movie_detail_screen.dart';
import '../../features/player/live_player_screen.dart';
import '../../features/player/vod_player_screen.dart';
import '../../features/player/series_player_screen.dart';
import '../../features/playlists/playlists_screen.dart';
import '../../features/playlists/add_playlist_screen.dart';
import '../../features/series/series_categories_screen.dart';
import '../../features/series/series_list_screen.dart';
import '../../features/series/series_detail_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/favourites/favourites_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/parental/pin_setup_screen.dart';
import '../../features/settings/account_screen.dart';
import '../../features/settings/category_manager_screen.dart';
import '../../features/settings/diagnostics_screen.dart';
import '../../features/profiles/profiles_screen.dart';
import '../../features/profiles/profile_select_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    routes: [
      // ── Full-screen routes (no shell) ─────────────────────────────────────
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: '/profiles/select',
        builder: (_, __) => const ProfileSelectScreen(),
      ),
      GoRoute(path: '/playlists', builder: (_, __) => const PlaylistsScreen()),
      GoRoute(path: '/playlists/add', builder: (_, __) => const AddPlaylistScreen()),

      GoRoute(
        path: '/player/live',
        pageBuilder: (_, state) => _noTransitionPage(
          LivePlayerScreen(args: state.extra as LivePlayerArgs),
        ),
      ),
      GoRoute(
        path: '/player/vod',
        pageBuilder: (_, state) => _noTransitionPage(
          VodPlayerScreen(args: state.extra as VodPlayerArgs),
        ),
      ),
      GoRoute(
        path: '/player/series',
        pageBuilder: (_, state) => _noTransitionPage(
          SeriesPlayerScreen(args: state.extra as SeriesPlayerArgs),
        ),
      ),

      // ── Main shell with persistent tabs ───────────────────────────────────
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, shell) => NoTransitionPage(
          child: HomeShell(navigationShell: shell),
        ),
        branches: [
          // Tab 0 — Home
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          ]),

          // Tab 1 — Live TV
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/live',
              builder: (_, __) => const LiveTwoPaneScreen(),
              routes: [
                GoRoute(
                  path: ':categoryId',
                  builder: (ctx, state) => LiveChannelsScreen(
                    categoryId: state.pathParameters['categoryId']!,
                    categoryName: state.uri.queryParameters['name'] ?? '',
                  ),
                ),
              ],
            ),
          ]),

          // Tab 2 — Movies
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/movies',
              builder: (_, __) => const MoviesCategoriesScreen(),
              routes: [
                // IMPORTANT: static 'detail' route MUST come before the dynamic
                // ':categoryId' route — GoRouter matches in declaration order and
                // ':categoryId' would swallow the literal "detail" segment first.
                GoRoute(
                  path: 'detail',
                  builder: (_, state) =>
                      MovieDetailScreen(vod: state.extra as VodStream),
                ),
                GoRoute(
                  path: ':categoryId',
                  builder: (ctx, state) => MoviesListScreen(
                    categoryId: state.pathParameters['categoryId']!,
                    categoryName: state.uri.queryParameters['name'] ?? '',
                  ),
                ),
              ],
            ),
          ]),

          // Tab 3 — Series
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/series',
              builder: (_, __) => const SeriesCategoriesScreen(),
              routes: [
                // Same ordering rule as movies above.
                GoRoute(
                  path: 'detail',
                  builder: (_, state) =>
                      SeriesDetailScreen(series: state.extra as SeriesStream),
                ),
                GoRoute(
                  path: ':categoryId',
                  builder: (ctx, state) => SeriesListScreen(
                    categoryId: state.pathParameters['categoryId']!,
                    categoryName: state.uri.queryParameters['name'] ?? '',
                  ),
                ),
              ],
            ),
          ]),

          // Tab 4 — Search
          StatefulShellBranch(routes: [
            GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
          ]),

          // Tab 5 — Favourites
          StatefulShellBranch(routes: [
            GoRoute(path: '/favourites', builder: (_, __) => const FavouritesScreen()),
          ]),

          // Tab 6 — Settings
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (_, __) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'playlists',
                  builder: (_, __) => const PlaylistsScreen(),
                ),
                GoRoute(
                  path: 'history',
                  builder: (_, __) => const HistoryScreen(),
                ),
                GoRoute(
                  path: 'parental',
                  builder: (_, __) => const PinSetupScreen(),
                ),
                GoRoute(
                  path: 'categories',
                  builder: (_, __) => const CategoryManagerScreen(),
                ),
                GoRoute(
                  path: 'account',
                  builder: (_, __) => const AccountScreen(),
                ),
                GoRoute(
                  path: 'profiles',
                  builder: (_, __) => const ProfilesScreen(),
                ),
                GoRoute(
                  path: 'diagnostics',
                  builder: (_, __) => const DiagnosticsScreen(),
                ),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
});

/// Players open as instant full-screen (no slide animation).
CustomTransitionPage<void> _noTransitionPage(Widget child) =>
    CustomTransitionPage<void>(
      child: child,
      transitionsBuilder: (_, __, ___, c) => c,
    );
