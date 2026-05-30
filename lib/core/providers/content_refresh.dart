import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/epg/epg_panel.dart';
import '../../features/live_tv/live_categories_screen.dart';
import '../../features/live_tv/live_channels_screen.dart';
import '../../features/movies/movie_detail_screen.dart';
import '../../features/movies/movies_categories_screen.dart';
import '../../features/movies/movies_list_screen.dart';
import '../../features/series/series_categories_screen.dart';
import '../../features/series/series_detail_screen.dart';
import '../../features/series/series_list_screen.dart';
import '../../features/settings/account_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Invalidate every cached content provider.
//
// The content providers are plain (session-cached) FutureProviders keyed off
// the active playlist. When the active playlist changes (added or switched),
// they must be invalidated so they re-fetch for the new endpoint — otherwise
// the UI keeps showing the previous playlist's lists & categories.
//
// Invalidating a `.family` provider with no argument clears ALL its instances.
// ─────────────────────────────────────────────────────────────────────────────

void invalidateAllContent(WidgetRef ref) {
  // Live TV
  ref.invalidate(liveCategoriesProvider);
  ref.invalidate(liveChannelsProvider);
  // Movies
  ref.invalidate(vodCategoriesProvider);
  ref.invalidate(allVodStreamsProvider);
  ref.invalidate(vodInfoProvider);
  // Series
  ref.invalidate(seriesCategoriesProvider);
  ref.invalidate(allSeriesProvider);
  ref.invalidate(seriesInfoProvider);
  // EPG + account
  ref.invalidate(epgProvider);
  ref.invalidate(accountInfoProvider);
}
