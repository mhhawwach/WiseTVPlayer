import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../perf/perf_profile.dart';
import '../theme/app_theme.dart';

/// TV-friendly card that highlights on D-pad focus and responds to
/// both tap (mobile) and OK/Select key (TV remote).
class FocusableCard extends StatefulWidget {
  const FocusableCard({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.borderRadius = 12.0,
    this.autofocus = false,
    this.focusNode,
    this.focusScale = 1.08,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final bool autofocus;
  final FocusNode? focusNode;

  /// Scale applied when focused/hovered. Use 1.0 for large elements (e.g. a
  /// full-width hero) where scaling would overflow.
  final double focusScale;

  @override
  State<FocusableCard> createState() => _FocusableCardState();
}

class _FocusableCardState extends State<FocusableCard> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (f) {
        if (mounted) setState(() => _focused = f);
        // Auto-scroll the focused item into view so D-pad navigation through
        // long rows / grids always keeps the selection on screen (TV remotes).
        if (f && Scrollable.maybeOf(context) != null) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onPressed?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress,
          // Scale the focused item up slightly so the selection is obvious
          // from across the room. On the low tier (reduce-motion) the zoom and
          // the expensive blur glow are dropped — but the bright border stays,
          // so focus is still unmistakable, just without the GPU cost.
          child: AnimatedScale(
            scale: (!Perf.reduceMotion && (_focused || _hovered))
                ? widget.focusScale
                : 1.0,
            duration: Perf.reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: Perf.reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                // Bright cyan, thick border so the focused item is unmistakable
                // from across the room on a TV — a different hue from the
                // (theme-coloured) "selected" state.
                border: Border.all(
                  color: _focused ? AppColors.focus : Colors.transparent,
                  width: 4.0,
                ),
                // The glow is GPU-cheap to skip, so it's dropped on low-end TVs
                // (Perf.reduceMotion). The border + foreground tint below stay,
                // so focus is still obvious there.
                boxShadow: (_focused && !Perf.reduceMotion)
                    ? [
                        BoxShadow(
                          color: AppColors.focus.withValues(alpha: 0.7),
                          blurRadius: 22,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              // A subtle cyan wash OVER the child guarantees the highlight is
              // visible even on opaque poster art (where a background fill would
              // be hidden). Stays on every tier so focus is never "lost".
              foregroundDecoration: _focused
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      color: AppColors.focus.withValues(alpha: 0.12),
                    )
                  : null,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
