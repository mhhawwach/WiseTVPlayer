import 'package:equatable/equatable.dart';

class VodStream extends Equatable {
  final int num;
  final String name;
  final int streamId;
  final String streamIcon;
  final String rating;
  final String ratingFiveItem;
  final String added;
  final String categoryId;
  final String containerExtension;
  final String customSid;
  final String directSource;

  const VodStream({
    required this.num,
    required this.name,
    required this.streamId,
    required this.streamIcon,
    required this.rating,
    required this.ratingFiveItem,
    required this.added,
    required this.categoryId,
    required this.containerExtension,
    required this.customSid,
    required this.directSource,
  });

  factory VodStream.fromJson(Map<String, dynamic> j) => VodStream(
        num: j['num'] is int ? j['num'] as int : int.tryParse(j['num']?.toString() ?? '0') ?? 0,
        name: j['name']?.toString() ?? '',
        streamId: j['stream_id'] is int
            ? j['stream_id'] as int
            : int.tryParse(j['stream_id']?.toString() ?? '0') ?? 0,
        streamIcon: j['stream_icon']?.toString() ?? '',
        rating: j['rating']?.toString() ?? '',
        ratingFiveItem: j['rating_5based']?.toString() ?? '',
        added: j['added']?.toString() ?? '',
        categoryId: j['category_id']?.toString() ?? '',
        containerExtension: j['container_extension']?.toString() ?? 'mp4',
        customSid: j['custom_sid']?.toString() ?? '',
        directSource: j['direct_source']?.toString() ?? '',
      );

  @override
  List<Object?> get props => [streamId];
}

class VodInfo {
  final Map<String, dynamic> info;
  final Map<String, dynamic> movieData;

  const VodInfo({required this.info, required this.movieData});

  factory VodInfo.fromJson(Map<String, dynamic> j) => VodInfo(
        info: j['info'] as Map<String, dynamic>? ?? {},
        movieData: j['movie_data'] as Map<String, dynamic>? ?? {},
      );

  String get plot => info['plot']?.toString() ?? '';
  String get director => info['director']?.toString() ?? '';
  String get cast => info['cast']?.toString() ?? '';
  String get genre => info['genre']?.toString() ?? '';
  String get releaseDate => info['releasedate']?.toString() ?? '';
  String get rating => info['rating']?.toString() ?? '';
  String get duration => info['duration']?.toString() ?? '';
  String get youtubeTrailer => info['youtube_trailer']?.toString() ?? '';
  String get backdropPath {
    final list = info['backdrop_path'];
    if (list is List && list.isNotEmpty) return list.first.toString();
    return '';
  }
}
