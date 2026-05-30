import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wisetv_player/core/storage/storage_service.dart';
import 'package:wisetv_player/data/models/profile.dart';

// Verifies the first-run profile migration in StorageService._bootstrapProfiles:
// existing un-prefixed favourites / history / scoped-settings must be re-keyed
// under a new "Main" profile so no user data is lost on upgrade.
void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('wisetv_mig_test');
    Hive.init(dir.path);

    // Simulate a pre-profiles install: open the raw boxes and seed old data
    // with un-prefixed keys, exactly as the previous app version wrote them.
    final fav = await Hive.openBox('favourites');
    await fav.put('vod:100', {'type': 'vod', 'id': 100, 'name': 'Old Movie'});
    await fav.put('live:200', {'type': 'live', 'id': 200, 'name': 'Old Chan'});

    final hist = await Hive.openBox('history');
    await hist.put('vod:100',
        {'type': 'vod', 'id': 100, 'ts': 1700000000000, 'position': 42});

    final settings = await Hive.openBox('settings');
    await settings.put('active_playlist_id', 'pl1');
    await settings.put('cat_hidden', <String>['cat_a']);

    // Boot the real storage layer (registers adapters, runs migration).
    await StorageService.init();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  test('creates a single Main profile and makes it active', () {
    expect(StorageService.profiles.length, 1);
    expect(StorageService.activeProfile, isNotNull);
    expect(StorageService.activeProfile!.name, 'Main');
    expect(StorageService.activeProfileId, isNotEmpty);
  });

  test('re-keys favourites under the active profile prefix', () {
    final fav = Hive.box('favourites');
    final prefix = '${StorageService.activeProfileId}_';

    // Old keys gone, prefixed keys present.
    expect(fav.containsKey('vod:100'), isFalse);
    expect(fav.containsKey('live:200'), isFalse);
    expect(fav.containsKey('${prefix}vod:100'), isTrue);
    expect(fav.containsKey('${prefix}live:200'), isTrue);
  });

  test('scoped getters see the migrated data', () {
    expect(StorageService.getFavourites('vod').length, 1);
    expect(StorageService.getFavourites('live').length, 1);
    expect(StorageService.isFavourite('vod', 100), isTrue);
    expect(StorageService.activePlaylistId, 'pl1');
    expect(StorageService.hiddenCategoryIds.contains('cat_a'), isTrue);
    expect(StorageService.getHistory().length, 1);
    expect(StorageService.getHistory().first['position'], 42);
  });

  test('switching to a new profile isolates favourites', () async {
    const kidsId = 'p_test_kids';
    await StorageService.saveProfile(Profile(
      id: kidsId,
      name: 'Kids',
      colorValue: 0xFF00B894,
    ));
    final kids = await StorageService.switchProfile(kidsId);

    expect(kids.name, 'Kids');
    // Fresh profile starts empty — no leakage from Main.
    expect(StorageService.getFavourites('vod'), isEmpty);
    expect(StorageService.isFavourite('vod', 100), isFalse);

    // Adding a favourite here must not appear in Main's set.
    await StorageService.toggleFavourite(
        'vod', 999, {'type': 'vod', 'id': 999});
    expect(StorageService.isFavourite('vod', 999), isTrue);
  });
}
