import 'package:equatable/equatable.dart';

class LiveStream extends Equatable {
  final int num;
  final String name;
  final String streamType;
  final int streamId;
  final String streamIcon;
  final String epgChannelId;
  final String added;
  final String categoryId;
  final String customSid;
  final String tvArchive;
  final String directSource;
  final String tvArchiveDuration;

  const LiveStream({
    required this.num,
    required this.name,
    required this.streamType,
    required this.streamId,
    required this.streamIcon,
    required this.epgChannelId,
    required this.added,
    required this.categoryId,
    required this.customSid,
    required this.tvArchive,
    required this.directSource,
    required this.tvArchiveDuration,
  });

  factory LiveStream.fromJson(Map<String, dynamic> j) => LiveStream(
        num: j['num'] is int ? j['num'] as int : int.tryParse(j['num']?.toString() ?? '0') ?? 0,
        name: j['name']?.toString() ?? '',
        streamType: j['stream_type']?.toString() ?? 'live',
        streamId: j['stream_id'] is int
            ? j['stream_id'] as int
            : int.tryParse(j['stream_id']?.toString() ?? '0') ?? 0,
        streamIcon: j['stream_icon']?.toString() ?? '',
        epgChannelId: j['epg_channel_id']?.toString() ?? '',
        added: j['added']?.toString() ?? '',
        categoryId: j['category_id']?.toString() ?? '',
        customSid: j['custom_sid']?.toString() ?? '',
        tvArchive: j['tv_archive']?.toString() ?? '0',
        directSource: j['direct_source']?.toString() ?? '',
        tvArchiveDuration: j['tv_archive_duration']?.toString() ?? '0',
      );

  bool get hasCatchUp => tvArchive == '1' || tvArchive == 'true';

  @override
  List<Object?> get props => [streamId];
}
