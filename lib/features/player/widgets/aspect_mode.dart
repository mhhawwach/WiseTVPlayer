import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/theme/app_theme.dart';

/// The five aspect-ratio modes the player cycles through.
enum AspectMode {
  contain('Contain', Icons.fit_screen_outlined),
  cover('Cover', Icons.crop_free_rounded),
  fill('Fill', Icons.fullscreen_rounded),
  ratio16x9('16:9', Icons.crop_16_9_outlined),
  ratio4x3('4:3', Icons.crop_outlined);

  const AspectMode(this.label, this.icon);
  final String label;
  final IconData icon;

  AspectMode get next {
    final idx = AspectMode.values.indexOf(this);
    return AspectMode.values[(idx + 1) % AspectMode.values.length];
  }
}

/// Wraps a [VideoController]'s output with the chosen [AspectMode].
class AspectModeVideo extends StatelessWidget {
  const AspectModeVideo({
    super.key,
    required this.controller,
    required this.mode,
  });

  final VideoController controller;
  final AspectMode mode;

  @override
  Widget build(BuildContext context) {
    return switch (mode) {
      // Default: letterbox / pillarbox — nothing is cropped.
      AspectMode.contain => Video(
          controller: controller,
          fill: Colors.black,
          fit: BoxFit.contain,
        ),

      // Fill entire screen, cropping if necessary.
      AspectMode.cover => Video(
          controller: controller,
          fill: Colors.black,
          fit: BoxFit.cover,
        ),

      // Stretch to fill (distorts if source AR differs from screen).
      AspectMode.fill => Video(
          controller: controller,
          fill: Colors.black,
          fit: BoxFit.fill,
        ),

      // Force 16:9 box, then fill it.
      AspectMode.ratio16x9 => Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Video(
              controller: controller,
              fill: Colors.black,
              fit: BoxFit.fill,
            ),
          ),
        ),

      // Force 4:3 box, then fill it.
      AspectMode.ratio4x3 => Center(
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Video(
              controller: controller,
              fill: Colors.black,
              fit: BoxFit.fill,
            ),
          ),
        ),
    };
  }
}

/// Compact button that shows the current mode label and cycles on tap.
///
/// Focusable so a TV remote can reach it via the D-pad; draws a highlight ring
/// when focused and cycles on OK / Enter / Select as well as on tap.
class AspectModeButton extends StatefulWidget {
  const AspectModeButton({
    super.key,
    required this.mode,
    required this.onCycle,
    this.focusNode,
    this.autofocus = false,
  });

  final AspectMode mode;
  final VoidCallback onCycle;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<AspectModeButton> createState() => _AspectModeButtonState();
}

class _AspectModeButtonState extends State<AspectModeButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (f) {
        if (mounted) setState(() => _focused = f);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onCycle();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onCycle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _focused
                ? AppColors.focus.withValues(alpha: 0.32)
                : Colors.white.withAlpha(26),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _focused ? AppColors.focus : Colors.transparent,
              width: 3.0,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: AppColors.focus.withValues(alpha: 0.65),
                      blurRadius: 12,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.mode.icon, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                widget.mode.label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
