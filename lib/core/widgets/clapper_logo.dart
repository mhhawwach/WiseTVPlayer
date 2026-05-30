import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClapperLogo — the WiseVOD app mark, drawn natively.
//
// A film clapperboard with a play triangle cut into the slate ("movies" + "play"
// in one), on the teal→cyan→blue brand gradient. Faithfully recreates
// logo-export/svg/wisevod-clapper-play.svg (100-unit mark space placed via
// translate(136,124) scale(2.4) on a 512 canvas).
//
// When [animate] is true the clapper stick claps open and snaps shut on a loop —
// a native reproduction of the animated SVG (which can't run on-device).
// ─────────────────────────────────────────────────────────────────────────────

class ClapperLogo extends StatefulWidget {
  const ClapperLogo({
    super.key,
    this.size = 116,
    this.animate = false,
  });

  final double size;
  final bool animate;

  @override
  State<ClapperLogo> createState() => _ClapperLogoState();
}

class _ClapperLogoState extends State<ClapperLogo>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  late Animation<double> _clap;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1700),
      );
      // Open smoothly, hold, snap shut fast, then pause before the next clap.
      _clap = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 32,
        ),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 12),
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeInBack)),
          weight: 14,
        ),
        TweenSequenceItem(tween: ConstantTween(0.0), weight: 42),
      ]).animate(_ctrl!);
      _ctrl!.repeat();
    } else {
      _clap = const AlwaysStoppedAnimation(0.0);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _clap,
          builder: (_, __) => CustomPaint(
            painter: _ClapperPainter(_clap.value.clamp(0.0, 1.0)),
            size: Size(widget.size, widget.size),
          ),
        ),
      ),
    );
  }
}

class _ClapperPainter extends CustomPainter {
  _ClapperPainter(this.clapT);

  /// 0 = clapper shut, 1 = clapper fully open.
  final double clapT;

  // Brand gradient tokens (see logo-export/HANDOFF.md).
  static const _g0 = Color(0xFF18D6C0); // teal
  static const _g1 = Color(0xFF28A9EA); // cyan (≈46%)
  static const _g2 = Color(0xFF4A5CF0); // blue

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 512.0;
    canvas.scale(s);

    // ── Tile: rounded-rect gradient (corner radius 22.3% ≈ 114/512) ──────────
    final tileRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 512, 512),
      const Radius.circular(114),
    );
    final tilePaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(512, 512),
        const [_g0, _g1, _g2],
        const [0.0, 0.46, 1.0],
      );
    canvas.drawRRect(tileRect, tilePaint);

    // ── Sheen: soft white highlight, top-left ────────────────────────────────
    final sheenPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(0.22 * 512, 0.12 * 512),
        0.95 * 512,
        [Colors.white.withValues(alpha: 0.30), Colors.white.withValues(alpha: 0)],
        const [0.0, 0.55],
      );
    canvas.drawRRect(tileRect, sheenPaint);

    // ── Mark space: translate(136,124) scale(2.4) ────────────────────────────
    canvas.save();
    canvas.translate(136, 124);
    canvas.scale(2.4);

    final white = Paint()
      ..color = Colors.white
      ..isAntiAlias = true;

    // Slate (static): rounded rect (14,45)-(86,85) r7.5 with play-triangle hole.
    final slate = Path()..fillType = PathFillType.evenOdd;
    slate.addRRect(RRect.fromRectAndRadius(
      const Rect.fromLTRB(14, 45, 86, 85),
      const Radius.circular(7.5),
    ));
    slate
      ..moveTo(44, 56)
      ..lineTo(44, 74)
      ..lineTo(62, 65)
      ..close();
    canvas.drawPath(slate, white);

    // Clapper stick: bar (13,28)-(87,43) r3.5 with 4 diagonal stripe holes.
    final clapper = Path()..fillType = PathFillType.evenOdd;
    clapper.addRRect(RRect.fromRectAndRadius(
      const Rect.fromLTRB(13, 28, 87, 43),
      const Radius.circular(3.5),
    ));
    for (final x in const [26.0, 42.0, 58.0, 74.0]) {
      clapper
        ..moveTo(x, 28)
        ..lineTo(x + 5, 28)
        ..lineTo(x - 3, 43)
        ..lineTo(x - 8, 43)
        ..close();
    }

    // Clap: rotate the stick around its left hinge. Negative angle lifts the
    // right (free) end upward in this y-down space → "opens".
    const pivot = Offset(15, 43);
    final angle = -0.46 * clapT;
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.drawPath(clapper, white);
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ClapperPainter old) => old.clapT != clapT;
}
