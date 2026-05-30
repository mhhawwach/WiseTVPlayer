import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps a scrollable (e.g. a [CustomScrollView]) so a TV remote can navigate
/// long detail pages.
///
/// On D-pad Up/Down it first tries to move focus in that direction (the focus
/// framework auto-scrolls the newly focused widget into view). When there is no
/// focusable widget in that direction — e.g. the read-only overview below a
/// movie's "Play Now" button — it scrolls the page by one step instead, so the
/// content below the fold is never unreachable ("stuck at Play Now").
///
/// [controller] must be the same [ScrollController] given to the [child]
/// scrollable. The wrapper itself never holds focus; it only reacts to key
/// events bubbling up from the focused descendant, so a descendant should be
/// focused (autofocus your primary action).
class DpadScrollable extends StatelessWidget {
  const DpadScrollable({
    super.key,
    required this.controller,
    required this.child,
    this.step = 320,
  });

  final ScrollController controller;
  final Widget child;

  /// Pixels to scroll per key press when focus can't move further.
  final double step;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final TraversalDirection? dir;
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          dir = TraversalDirection.down;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          dir = TraversalDirection.up;
        } else {
          dir = null;
        }
        if (dir == null) return KeyEventResult.ignored;

        // Prefer moving focus (framework scrolls it into view).
        final moved = FocusScope.of(context).focusInDirection(dir);
        if (moved) return KeyEventResult.handled;

        // No focusable target that way — scroll the page so read-only content
        // below/above the fold is still reachable.
        if (controller.hasClients) {
          final pos = controller.position;
          final atEdge = dir == TraversalDirection.down
              ? controller.offset >= pos.maxScrollExtent
              : controller.offset <= pos.minScrollExtent;
          if (!atEdge) {
            final target = (controller.offset +
                    (dir == TraversalDirection.down ? step : -step))
                .clamp(pos.minScrollExtent, pos.maxScrollExtent);
            controller.animateTo(
              target,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
