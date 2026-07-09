import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Creates a [FocusNode] for an on-screen search / text field that lets a TV
/// remote's D-pad escape the field.
///
/// A focused text editor normally swallows Up/Down (it treats them as cursor
/// movement), so the user gets stuck on the search box and can't reach the grid
/// below. Because a node's own `onKeyEvent` fires *before* the editor's internal
/// shortcuts, this node intercepts Up/Down first and moves focus out of the
/// field instead. Left/Right are left untouched so the cursor can still move
/// while typing.
FocusNode searchEscapeFocusNode() => FocusNode(
      debugLabel: 'tv-search',
      onKeyEvent: (node, e) {
        if (e is KeyDownEvent || e is KeyRepeatEvent) {
          if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
            node.focusInDirection(TraversalDirection.down);
            return KeyEventResult.handled;
          }
          if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
            node.focusInDirection(TraversalDirection.up);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );
