import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/focusable_card.dart';

/// Backspace key value passed to [PinNumPad.onKey].
const pinBackspace = '⌫';

/// Lets remotes / keyboards with digit keys type straight into a PIN pad.
/// Only listens to keys bubbling up from the focused pad key — it never holds
/// focus itself (an invisible focusable here could swallow the D-pad).
class PinHardwareKeys extends StatelessWidget {
  const PinHardwareKeys({super.key, required this.onKey, required this.child});

  final ValueChanged<String> onKey;
  final Widget child;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      onKey(pinBackspace);
      return KeyEventResult.handled;
    }
    final ch = e.character;
    if (ch != null && ch.length == 1 && '0123456789'.contains(ch)) {
      onKey(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKeyEvent,
        child: child,
      );
}

/// Four PIN progress dots.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, required this.error});
  final int length;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: error
                ? AppColors.liveRed
                : filled
                    ? AppColors.primary
                    : Colors.transparent,
            border: Border.all(
              color: error
                  ? AppColors.liveRed
                  : filled
                      ? AppColors.primary
                      : AppColors.textMuted,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

/// D-pad navigable number pad (each key is focusable; OK presses it). The
/// centre "5" takes initial focus — the fewest presses to any digit.
class PinNumPad extends StatelessWidget {
  const PinNumPad({super.key, required this.onKey});
  final ValueChanged<String> onKey;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', pinBackspace],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _rows.map((row) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: row.map((k) {
            if (k.isEmpty) return const SizedBox(width: 76, height: 64);
            return Padding(
              padding: const EdgeInsets.all(4),
              child: FocusableCard(
                autofocus: k == '5',
                borderRadius: 8,
                focusScale: 1.04,
                semanticLabel: k == pinBackspace ? 'Backspace' : k,
                onPressed: () => onKey(k),
                child: Container(
                  width: 68,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: k == pinBackspace
                        ? const Icon(Icons.backspace_outlined,
                            color: AppColors.textSecondary, size: 20)
                        : Text(k,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
