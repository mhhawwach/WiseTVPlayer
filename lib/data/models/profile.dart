import 'package:hive_flutter/hive_flutter.dart';

part 'profile.g.dart';

@HiveType(typeId: 1)
class Profile extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  /// A [Color.value] int used for the avatar circle.
  @HiveField(2)
  int colorValue;

  /// When true the profile is restricted to non-adult categories.
  @HiveField(3)
  bool isKidsMode;

  /// Emoji shown as the profile avatar.
  @HiveField(4)
  String emoji;

  Profile({
    required this.id,
    required this.name,
    required this.colorValue,
    this.isKidsMode = false,
    this.emoji = '🍿',
  });

  /// Short key prefix applied to every scoped Hive entry.
  String get prefix => '${id}_';
}
