import 'dart:convert';
import 'package:equatable/equatable.dart';

class EpgListing extends Equatable {
  final String id;
  final String epgId;
  final String title;
  final String lang;
  final String start;
  final String end;
  final String description;
  final String channelId;
  final String startTimestamp;
  final String stopTimestamp;
  final bool nowPlaying;
  final bool hasArchive;

  const EpgListing({
    required this.id,
    required this.epgId,
    required this.title,
    required this.lang,
    required this.start,
    required this.end,
    required this.description,
    required this.channelId,
    required this.startTimestamp,
    required this.stopTimestamp,
    required this.nowPlaying,
    required this.hasArchive,
  });

  factory EpgListing.fromJson(Map<String, dynamic> j) => EpgListing(
        id: j['id']?.toString() ?? '',
        epgId: j['epg_id']?.toString() ?? '',
        title: _decodeBase64(j['title']?.toString() ?? ''),
        lang: j['lang']?.toString() ?? '',
        start: j['start']?.toString() ?? '',
        end: j['end']?.toString() ?? '',
        description: _decodeBase64(j['description']?.toString() ?? ''),
        channelId: j['channel_id']?.toString() ?? '',
        startTimestamp: j['start_timestamp']?.toString() ?? '',
        stopTimestamp: j['stop_timestamp']?.toString() ?? '',
        nowPlaying: j['now_playing'] == 1 || j['now_playing'] == true,
        hasArchive: j['has_archive'] == 1 || j['has_archive'] == true,
      );

  static String _decodeBase64(String s) {
    if (s.isEmpty) return s;
    try {
      return utf8.decode(base64.decode(s));
    } catch (_) {
      return s;
    }
  }

  DateTime? get startTime {
    final ts = int.tryParse(startTimestamp);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  }

  DateTime? get stopTime {
    final ts = int.tryParse(stopTimestamp);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  }

  double get progressPercent {
    final s = startTime;
    final e = stopTime;
    if (s == null || e == null) return 0;
    final now = DateTime.now();
    if (now.isBefore(s) || now.isAfter(e)) return 0;
    final total = e.difference(s).inSeconds;
    final elapsed = now.difference(s).inSeconds;
    return total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0;
  }

  @override
  List<Object?> get props => [id];
}
