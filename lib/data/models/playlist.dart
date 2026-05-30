import 'package:hive_flutter/hive_flutter.dart';

part 'playlist.g.dart';

@HiveType(typeId: 0)
class Playlist extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String serverUrl; // e.g. http://myserver.com:8080

  @HiveField(3)
  String username;

  @HiveField(4)
  String password;

  @HiveField(5)
  DateTime addedAt;

  @HiveField(6)
  DateTime? expiryDate;

  @HiveField(7)
  bool isActive;

  Playlist({
    required this.id,
    required this.name,
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.addedAt,
    this.expiryDate,
    this.isActive = true,
  });

  String get baseUrl => serverUrl.replaceAll(RegExp(r'/$'), '');

  String liveStreamUrl(String streamId, String ext) =>
      '$baseUrl/live/$username/$password/$streamId.$ext';

  String vodStreamUrl(String streamId, String ext) =>
      '$baseUrl/movie/$username/$password/$streamId.$ext';

  String seriesStreamUrl(String streamId, String ext) =>
      '$baseUrl/series/$username/$password/$streamId.$ext';

  String get apiBase => '$baseUrl/player_api.php?username=$username&password=$password';

  /// Xtream Codes timeshift / catch-up URL.
  ///
  /// [streamId]  — the live stream ID.
  /// [startUtc]  — recording start as UTC Unix timestamp (seconds).
  /// [stopUtc]   — recording end as UTC Unix timestamp (seconds).
  ///
  /// Uses the `utc/lutc` query-parameter format, which is broadly supported.
  /// Some servers also accept `/timeshift/{user}/{pass}/{hours}/{YYYY-MM-DD:HH-MM}/{id}.ts`
  /// — if your server only supports that, swap the URL below.
  String catchUpUrl(String streamId, int startUtc, int stopUtc) =>
      '$baseUrl/live/$username/$password/$streamId.ts'
      '?utc=$startUtc&lutc=$stopUtc';

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  int get daysLeft {
    if (expiryDate == null) return -1;
    return expiryDate!.difference(DateTime.now()).inDays;
  }
}
