import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// A focusable, D-pad-activatable icon button for the video player overlays.
///
/// The native overlay buttons used to be plain [IconButton]s that the outer
/// player [Focus] never handed focus to, so on a TV remote the controls were
/// completely unreachable. This widget is explicitly focusable, activates on
/// OK / Enter / Select, and draws a bold highlight ring when focused so the
/// selection is obvious from across the room.
class PlayerControlButton extends StatefulWidget {
  const PlayerControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
    this.iconColor = Colors.white70,
    this.iconSize = 22,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? tooltip;

  /// Resting icon colour (when not focused / not active).
  final Color iconColor;
  final double iconSize;

  /// When true the icon is tinted with the accent colour even when unfocused
  /// (used for toggle buttons such as Stats-for-Nerds).
  final bool active;

  @override
  State<PlayerControlButton> createState() => _PlayerControlButtonState();
}

class _PlayerControlButtonState extends State<PlayerControlButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final Color iconColor = !enabled
        ? Colors.white24
        : (widget.active ? AppColors.primary : widget.iconColor);

    Widget button = Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      canRequestFocus: enabled,
      skipTraversal: !enabled,
      onFocusChange: (f) {
        if (mounted) setState(() => _focused = f);
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
        cursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _focused
                  ? AppColors.primary.withValues(alpha: 0.30)
                  : Colors.transparent,
              border: Border.all(
                color: _focused ? AppColors.primary : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.6),
                        blurRadius: 14,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Icon(widget.icon, color: iconColor, size: widget.iconSize),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}
