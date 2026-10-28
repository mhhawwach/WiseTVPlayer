import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisetv_player/features/player/widgets/aspect_mode.dart';
import 'package:wisetv_player/features/player/widgets/playback_watchdog.dart';
import 'package:wisetv_player/services/player/app_player.dart';

class _FakePlayer extends AppPlayer {
  final position = StreamController<Duration>.broadcast();
  final playing = StreamController<bool>.broadcast();
  final errors = StreamController<String>.broadcast();
  bool isPlaying = true;

  @override
  AppPlayerState get state => AppPlayerState(playing: isPlaying);
  @override
  Stream<Duration> get positionStream => position.stream;
  @override
  Stream<Duration> get durationStream => const Stream.empty();
  @override
  Stream<bool> get playingStream => playing.stream;
  @override
  Stream<bool> get bufferingStream => const Stream.empty();
  @override
  Stream<Duration> get bufferStream => const Stream.empty();
  @override
  Stream<String> get errorStream => errors.stream;
  @override
  AppTracks get tracks => const AppTracks();
  @override
  AppTrack get selectedVideoTrack => AppTrack.auto;
  @override
  AppTrack get selectedAudioTrack => AppTrack.auto;
  @override
  AppTrack get selectedSubtitleTrack => AppTrack.none;
  @override
  Future<void> open(String url) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> playOrPause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setVideoTrack(AppTrack track) async {}
  @override
  Future<void> setAudioTrack(AppTrack track) async {}
  @override
  Future<void> setSubtitleTrack(AppTrack track) async {}
  @override
  Future<void> dispose() async {}
  @override
  Widget buildVideoWidget(BuildContext context, AspectMode mode) =>
      const SizedBox();
}

void main() {
  late _FakePlayer player;
  late DateTime now;
  final failures = <String>[];

  PlaybackWatchdog watch({bool Function()? onStall}) => PlaybackWatchdog(
        player: player,
        onFailure: failures.add,
        onStall: onStall,
        openTimeout: const Duration(seconds: 20),
        stallTimeout: const Duration(seconds: 15),
        clock: () => now,
      );

  // Advances the injected clock and the fake-async timers together.
  Future<void> elapse(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }

  setUp(() {
    player = _FakePlayer();
    now = DateTime(2026);
    failures.clear();
  });

  testWidgets('a stream that never starts fails after the open timeout',
      (tester) async {
    final dog = watch();
    await elapse(tester, 19);
    expect(failures, isEmpty);
    await elapse(tester, 2);
    expect(failures, hasLength(1));
    dog.dispose();
  });

  testWidgets('progress keeps it quiet; a freeze triggers a stall',
      (tester) async {
    var stalls = 0;
    final dog = watch(onStall: () {
      stalls++;
      return true; // caller re-opens the stream
    });
    for (var s = 1; s <= 30; s++) {
      player.position.add(Duration(seconds: s));
      await elapse(tester, 1);
    }
    expect(stalls, 0);
    await elapse(tester, 16); // frozen
    expect(stalls, 1);
    expect(failures, isEmpty);
    dog.dispose();
  });

  testWidgets('a pause is not a stall', (tester) async {
    final dog = watch();
    player.position.add(const Duration(seconds: 1));
    await elapse(tester, 1);
    player.isPlaying = false;
    await elapse(tester, 60);
    expect(failures, isEmpty);
    dog.dispose();
  });

  testWidgets('an engine error fails only if playback does not continue',
      (tester) async {
    final dog = watch();
    player.position.add(const Duration(seconds: 1));
    player.errors.add('decoder hiccup');
    await elapse(tester, 1);
    for (var s = 2; s <= 10; s++) {
      player.position.add(Duration(seconds: s));
      await elapse(tester, 1);
    }
    expect(failures, isEmpty);

    player.errors.add('Failed to open http://host/live/user/pass/1.ts');
    await elapse(tester, 6);
    expect(failures, hasLength(1));
    expect(failures.single, isNot(contains('pass')));
    dog.dispose();
  });

  test('playbackErrorText strips URLs (they carry the account login)', () {
    expect(playbackErrorText('Failed to open http://h:80/movie/u/p/1.mp4.'),
        'Failed to open');
    expect(playbackErrorText(null), 'Playback error.');
  });
}
