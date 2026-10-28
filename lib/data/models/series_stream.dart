import 'package:equatable/equatable.dart';

class SeriesStream extends Equatable {
  final int num;
  final String name;
  final int seriesId;
  final String cover;
  final String plot;
  final String cast;
  final String director;
  final String genre;
  final String releaseDate;
  final String lastModified;
  final String rating;
  final String ratingFiveItem;
  final String backdropPath;
  final String youtubeTrailer;
  final int episodeRunTime;
  final String categoryId;

  const SeriesStream({
    required this.num,
    required this.name,
    required this.seriesId,
    required this.cover,
    required this.plot,
    required this.cast,
    required this.director,
    required this.genre,
    required this.releaseDate,
    required this.lastModified,
    required this.rating,
    required this.ratingFiveItem,
    required this.backdropPath,
    required this.youtubeTrailer,
    required this.episodeRunTime,
    required this.categoryId,
  });

  factory SeriesStream.fromJson(Map<String, dynamic> j) => SeriesStream(
        num: j['num'] is int ? j['num'] as int : int.tryParse(j['num']?.toString() ?? '0') ?? 0,
        name: j['name']?.toString() ?? '',
        seriesId: j['series_id'] is int
            ? j['series_id'] as int
            : int.tryParse(j['series_id']?.toString() ?? '0') ?? 0,
        cover: j['cover']?.toString() ?? '',
        plot: j['plot']?.toString() ?? '',
        cast: j['cast']?.toString() ?? '',
        director: j['director']?.toString() ?? '',
        genre: j['genre']?.toString() ?? '',
        releaseDate: j['releaseDate']?.toString() ?? '',
        lastModified: j['last_modified']?.toString() ?? '',
        rating: j['rating']?.toString() ?? '',
        ratingFiveItem: j['rating_5based']?.toString() ?? '',
        backdropPath: _firstUrl(j['backdrop_path']),
        youtubeTrailer: j['youtube_trailer']?.toString() ?? '',
        episodeRunTime: _runTimeMinutes(j['episode_run_time']),
        categoryId: j['category_id']?.toString() ?? '',
      );

  // Xtream sends backdrop_path as a LIST of URLs (stringifying it gives the
  // invalid "[http://…]"). Cached entries may hold that stringified form.
  static String _firstUrl(Object? value) {
    if (value is List) return value.isEmpty ? '' : value.first?.toString() ?? '';
    final s = value?.toString().trim() ?? '';
    if (!s.startsWith('[')) return s;
    final inner = s.substring(1, s.endsWith(']') ? s.length - 1 : s.length);
    return inner.split(',').first.trim().replaceAll('"', '');
  }

  // Providers mix minutes (45) and seconds (1200 = 20 min). No episode runs
  // longer than five hours, so larger values are seconds; 0 hides the chip.
  static int _runTimeMinutes(Object? value) {
    final raw = value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
    final minutes = raw > 300 ? (raw / 60).round() : raw;
    return minutes > 0 && minutes <= 300 ? minutes : 0;
  }

  @override
  List<Object?> get props => [seriesId];
}

class SeriesInfo {
  final Map<String, dynamic> info;
  final Map<String, List<SeriesEpisode>> episodes;
  final List<SeriesSeason> seasons;

  const SeriesInfo({
    required this.info,
    required this.episodes,
    required this.seasons,
  });

  factory SeriesInfo.fromJson(Map<String, dynamic> j) {
    final rawEpisodes = j['episodes'] as Map<String, dynamic>? ?? {};
    final episodes = rawEpisodes.map(
      (k, v) => MapEntry(
        k,
        (v as List).map((e) => SeriesEpisode.fromJson(e as Map<String, dynamic>)).toList(),
      ),
    );
    final rawSeasons = j['seasons'] as List? ?? [];
    final seasons = rawSeasons.map((s) => SeriesSeason.fromJson(s as Map<String, dynamic>)).toList();
    return SeriesInfo(
      info: j['info'] as Map<String, dynamic>? ?? {},
      episodes: episodes,
      seasons: seasons,
    );
  }

  List<String> get seasonNumbers => episodes.keys.toList()..sort();
}

class SeriesSeason {
  final int id;
  final String name;
  final int season;
  final String cover;
  final String overview;
  final String airDate;

  SeriesSeason({
    required this.id,
    required this.name,
    required this.season,
    required this.cover,
    required this.overview,
    required this.airDate,
  });

  factory SeriesSeason.fromJson(Map<String, dynamic> j) => SeriesSeason(
        id: j['id'] is int ? j['id'] as int : int.tryParse(j['id']?.toString() ?? '0') ?? 0,
        name: j['name']?.toString() ?? '',
        season: j['season_number'] is int
            ? j['season_number'] as int
            : int.tryParse(j['season_number']?.toString() ?? '0') ?? 0,
        cover: j['cover']?.toString() ?? j['cover_big']?.toString() ?? '',
        overview: j['overview']?.toString() ?? '',
        airDate: j['air_date']?.toString() ?? '',
      );
}

class SeriesEpisode {
  final int id;
  final String title;
  final String containerExtension;
  final String info;
  final String customSid;
  final String added;
  final int season;
  final int episodeNum;
  final String directSource;

  const SeriesEpisode({
    required this.id,
    required this.title,
    required this.containerExtension,
    required this.info,
    required this.customSid,
    required this.added,
    required this.season,
    required this.episodeNum,
    required this.directSource,
  });

  factory SeriesEpisode.fromJson(Map<String, dynamic> j) => SeriesEpisode(
        id: j['id'] is int ? j['id'] as int : int.tryParse(j['id']?.toString() ?? '0') ?? 0,
        title: j['title']?.toString() ?? '',
        containerExtension: j['container_extension']?.toString() ?? 'mp4',
        info: j['info']?.toString() ?? '',
        customSid: j['custom_sid']?.toString() ?? '',
        added: j['added']?.toString() ?? '',
        season: j['season'] is int ? j['season'] as int : int.tryParse(j['season']?.toString() ?? '0') ?? 0,
        episodeNum: j['episode_num'] is int
            ? j['episode_num'] as int
            : int.tryParse(j['episode_num']?.toString() ?? '0') ?? 0,
        directSource: j['direct_source']?.toString() ?? '',
      );
}
