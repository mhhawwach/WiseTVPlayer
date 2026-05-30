import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/player/app_player.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ResolutionBadge — a tiny, transparent pill in the corner showing the current
// video resolution (e.g. 4K, 1080p, 720p). Persistent and non-distracting;
// polls the player state at low frequency since resolution rarely changes.
// ─────────────────────────────────────────────────────────────────────────────

class ResolutionBadge extends StatefulWidget {
  const ResolutionBadge({super.key, required this.player});

  final AppPlayer player;

  @override
  State<ResolutionBadge> createState() => _ResolutionBadgeState();
}

class _ResolutionBadgeState extends State<ResolutionBadge> {
  Timer? _timer;
  String _label = '';

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _refresh());
  }

  void _refresh() {
    if (!mounted) return;
    final s = widget.player.state;
    final next = _labelFor(s.videoWidth, s.videoHeight);
    if (next != _label) setState(() => _label = next);
  }

  static String _labelFor(int? w, int? h) {
    if (h == null || h <= 0) return '';
    if (h >= 2100) return '4K';
    if (h >= 1400) return '1440p';
    if (h >= 1040) return '1080p';
    if (h >= 700) return '720p';
    if (h >= 560) return '576p';
    if (h >= 460) return '480p';
    return '${h}p';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_label.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.40),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.5),
        ),
        child: Text(
          _label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
