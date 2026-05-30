import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/player/app_player.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Stats for Nerds overlay — modelled after YouTube's implementation.
//
// Polls AppPlayerState at 1 Hz to display:
//   • Playback status, buffer health, position
//   • Video resolution, codec, FPS, bitrate, pixel format, colour space
//   • Audio codec, sample rate, channels, bitrate
//   • Stream URL (last 55 chars, for debugging)
//   • Estimated network throughput (rolling 5-sample average)
// ─────────────────────────────────────────────────────────────────────────────

class StatsOverlay extends StatefulWidget {
  const StatsOverlay({
    super.key,
    required this.player,
    this.streamUrl = '',
    required this.onClose,
  });

  final AppPlayer player;
  final String streamUrl;
  final VoidCallback onClose;

  @override
  State<StatsOverlay> createState() => _StatsOverlayState();
}

class _StatsOverlayState extends State<StatsOverlay> {
  Timer? _timer;

  Duration _prevBuffer   = Duration.zero;
  Duration _prevPosition = Duration.zero;
  double _estSpeedKbps = 0;
  Duration _bufferingFor = Duration.zero;

  @override
  void initState() {
    super.initState();
    _prevBuffer   = widget.player.state.buffer;
    _prevPosition = widget.player.state.position;
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _tick(Timer _) {
    if (!mounted) return;
    final s      = widget.player.state;
    final curBuf = s.buffer;
    final curPos = s.position;

    // ── Live download estimate ────────────────────────────────────────────
    // Content pulled this tick = consumed (position advance) + buffer growth,
    // × the stream bitrate. In steady real-time playback this ≈ bitrate; while
    // the buffer fills it spikes. Recomputed EVERY tick so it never freezes
    // (the old code only updated when the buffer/position changed, so it stuck
    // on live streams whose position doesn't advance).
    final bitrateKbps =
        ((s.videoBitrateKbps ?? 0) + (s.audioBitrateKbps ?? 0)).toDouble();
    if (bitrateKbps > 0) {
      final posDeltaSec = (curPos - _prevPosition).inMilliseconds / 1000.0;
      final bufDeltaSec = (curBuf - _prevBuffer).inMilliseconds / 1000.0;
      final pulledSec = posDeltaSec + bufDeltaSec;
      final instKbps = (!s.buffering && pulledSec > 0)
          ? pulledSec * bitrateKbps
          : bitrateKbps;
      // Light EMA so it reads live without being jumpy.
      _estSpeedKbps =
          _estSpeedKbps <= 0 ? instKbps : _estSpeedKbps * 0.4 + instKbps * 0.6;
    } else {
      _estSpeedKbps = 0;
    }

    // ── Buffering duration counter ────────────────────────────────────────
    if (s.buffering) {
      _bufferingFor += const Duration(seconds: 1);
    } else {
      _bufferingFor = Duration.zero;
    }

    _prevBuffer   = curBuf;
    _prevPosition = curPos;
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _fmtDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = widget.player.state;

    // Buffer health colour
    final bufSec = s.buffer.inMilliseconds / 1000.0;
    final bufColor = s.buffering
        ? const Color(0xFFFF6B35)
        : bufSec >= 5
            ? const Color(0xFF00D4AA)
            : bufSec >= 1
                ? const Color(0xFFFFB300)
                : const Color(0xFFFF3B30);

    // Status
    final statusText = s.buffering
        ? (_bufferingFor.inSeconds > 30
            ? 'Buffering (${_bufferingFor.inSeconds}s — stream may be down)'
            : 'Buffering (${_bufferingFor.inSeconds}s)…')
        : s.playing
            ? 'Playing'
            : 'Paused';

    final statusColor = s.buffering
        ? const Color(0xFFFFB300)
        : s.playing
            ? const Color(0xFF00D4AA)
            : Colors.white54;

    // Download throughput: prefer the measured buffer-growth estimate; fall
    // back to the stream's demux bitrate (video + audio) for a live readout.
    final streamKbps = (s.videoBitrateKbps ?? 0) + (s.audioBitrateKbps ?? 0);
    final dlKbps = _estSpeedKbps > 0 ? _estSpeedKbps : streamKbps.toDouble();
    final dlText = dlKbps >= 1000
        ? '${(dlKbps / 1000).toStringAsFixed(1)} Mbps'
        : '${dlKbps.round()} kbps';

    // Truncate URL
    final url        = widget.streamUrl;
    final urlDisplay = url.length > 55
        ? '…${url.substring(url.length - 52)}'
        : url;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 290,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.analytics_outlined,
                    color: Color(0xFF6C63FF), size: 13),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Stats for Nerds',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.close_rounded,
                        color: Colors.white38, size: 15),
                  ),
                ),
              ],
            ),

            const _Divider(),

            // ── Playback ────────────────────────────────────────────────────
            const _SectionLabel('PLAYBACK'),
            _StatRow('Status', statusText, valueColor: statusColor),
            if (s.duration > Duration.zero)
              _StatRow('Position',
                  '${_fmtDur(s.position)} / ${_fmtDur(s.duration)}'),
            _StatRow(
              'Buffer',
              bufSec > 0
                  ? '${bufSec.toStringAsFixed(1)} s'
                  : s.buffering ? 'filling…' : '—',
              valueColor: bufColor,
            ),
            if (s.bufferingPercentage > 0)
              _StatRow('Buf %',
                  '${s.bufferingPercentage.toStringAsFixed(1)} %'),
            if (dlKbps > 0)
              _StatRow('Download', dlText,
                  valueColor: const Color(0xFF00D4AA)),
            const _Divider(),

            // ── Video ────────────────────────────────────────────────────────
            const _SectionLabel('VIDEO'),
            _StatRow(
              'Resolution',
              (s.videoWidth != null && s.videoHeight != null)
                  ? '${s.videoWidth} × ${s.videoHeight}'
                  : '—',
            ),
            if (s.videoFps != null && (s.videoFps ?? 0) > 0)
              _StatRow('Frame Rate', '${s.videoFps!.toStringAsFixed(2)} fps'),
            if (s.videoCodec?.isNotEmpty == true)
              _StatRow('Codec', s.videoCodec!.toUpperCase()),
            if (s.videoBitrateKbps != null)
              _StatRow('V-Bitrate', '${s.videoBitrateKbps} kbps'),
            if (s.pixelFormat?.isNotEmpty == true)
              _StatRow('Pixel Fmt', s.pixelFormat!),
            if (s.hwPixelFormat?.isNotEmpty == true)
              _StatRow('HW Fmt', s.hwPixelFormat!),
            if (s.colorMatrix?.isNotEmpty == true)
              _StatRow('Color', s.colorMatrix!),
            if (s.colorLevels?.isNotEmpty == true)
              _StatRow('Range', s.colorLevels!),

            const _Divider(),

            // ── Audio ────────────────────────────────────────────────────────
            const _SectionLabel('AUDIO'),
            _StatRow('Codec', s.audioCodec?.toUpperCase() ?? '—'),
            if (s.audioSampleRate?.isNotEmpty == true)
              _StatRow('Sample Rate', s.audioSampleRate!),
            _StatRow('Channels', s.audioChannels ?? '—'),
            if ((s.audioBitrateKbps ?? 0) > 0)
              _StatRow('A-Bitrate', '${s.audioBitrateKbps} kbps'),

            // ── Stream URL ───────────────────────────────────────────────────
            if (urlDisplay.isNotEmpty) ...[
              const _Divider(),
              const _SectionLabel('STREAM'),
              Text(
                urlDisplay,
                style: const TextStyle(
                  color: Colors.white30,
                  fontSize: 9,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tiny helpers
// ─────────────────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(color: Colors.white12, height: 10, thickness: 0.5);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF6C63FF),
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value, {this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10.5,
                height: 1.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white70,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
