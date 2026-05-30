// Stub compiled on non-web platforms so that conditional imports resolve.
// On Flutter Web, web_player_impl.dart is used instead.
import 'package:flutter/material.dart';
import '../../features/player/widgets/aspect_mode.dart';
import 'app_player.dart';

class WebPlayerImpl extends AppPlayer {
  @override AppPlayerState get state => const AppPlayerState();
  @override Stream<Duration> get positionStream  => const Stream.empty();
  @override Stream<Duration> get durationStream  => const Stream.empty();
  @override Stream<bool>     get playingStream   => const Stream.empty();
  @override Stream<bool>     get bufferingStream => const Stream.empty();
  @override Stream<Duration> get bufferStream    => const Stream.empty();
  @override AppTracks  get tracks              => const AppTracks();
  @override AppTrack   get selectedVideoTrack  => AppTrack.auto;
  @override AppTrack   get selectedAudioTrack  => AppTrack.auto;
  @override AppTrack   get selectedSubtitleTrack => AppTrack.none;
  @override Future<void> open(String url) async {}
  @override Future<void> play()        async {}
  @override Future<void> pause()       async {}
  @override Future<void> playOrPause() async {}
  @override Future<void> seek(Duration position) async {}
  @override Future<void> setVideoTrack(AppTrack t) async {}
  @override Future<void> setAudioTrack(AppTrack t) async {}
  @override Future<void> setSubtitleTrack(AppTrack t) async {}
  @override Future<void> dispose() async {}
  @override Widget buildVideoWidget(BuildContext context, AspectMode mode) =>
      const SizedBox.shrink();
}
