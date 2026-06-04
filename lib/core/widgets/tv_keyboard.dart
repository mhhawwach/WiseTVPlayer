import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'focusable_card.dart';

/// A fully D-pad-navigable on-screen keyboard for TVs whose system IME doesn't
/// hand the remote's arrows to the keyboard (so typing was impossible). Each key
/// is a focusable cell; OK presses it. A physical/USB keyboard also works — its
/// keystrokes are captured into the field.
///
/// Returns the entered text on "Done", or null if dismissed (Back).
Future<String?> showTvKeyboard(
  BuildContext context, {
  required String title,
  required String initial,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _TvKeyboardSheet(title: title, initial: initial),
  );
}

class _TvKeyboardSheet extends StatefulWidget {
  const _TvKeyboardSheet({required this.title, required this.initial});
  final String title;
  final String initial;

  @override
  State<_TvKeyboardSheet> createState() => _TvKeyboardSheetState();
}

class _TvKeyboardSheetState extends State<_TvKeyboardSheet> {
  late String _text = widget.initial;
  bool _shift = false;

  // Rows of character keys. The symbol row covers what IPTV URLs / logins need.
  static const _rows = <String>[
    '1234567890',
    'qwertyuiop',
    'asdfghjkl',
    'zxcvbnm',
    '.:/@-_~?&=',
  ];

  void _type(String ch) =>
      setState(() => _text += _shift ? ch.toUpperCase() : ch);
  void _backspace() {
    if (_text.isNotEmpty) setState(() => _text = _text.substring(0, _text.length - 1));
  }

  void _done() => Navigator.of(context).pop(_text);

  // Capture a physical / USB keyboard so users with one can just type.
  KeyEventResult _onHwKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    final ch = e.character;
    if (ch != null && ch.length == 1 && ch.codeUnitAt(0) >= 32) {
      setState(() => _text += ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _key(
    String label, {
    required VoidCallback onTap,
    bool autofocus = false,
    double width = 46,
    Color? color,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: FocusableCard(
        autofocus: autofocus,
        borderRadius: 8,
        onPressed: onTap,
        child: Container(
          width: width,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color ?? AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: icon != null
              ? Icon(icon, color: Colors.white, size: 20)
              : Text(label,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _onHwKey,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(widget.title,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              // Live preview of what's typed.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text(
                  _text.isEmpty ? ' ' : _text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
                ),
              ),
              const SizedBox(height: 10),
              for (var r = 0; r < _rows.length; r++)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final c in _rows[r].split(''))
                      _key(_shift ? c.toUpperCase() : c,
                          autofocus: r == 1 && c == 'q',
                          onTap: () => _type(c)),
                  ],
                ),
              // Control row.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _key('', // Caps
                      icon: Icons.keyboard_capslock_rounded,
                      color: _shift ? AppColors.primary : null,
                      onTap: () => setState(() => _shift = !_shift)),
                  _key('Space', width: 220, onTap: () => setState(() => _text += ' ')),
                  _key('', icon: Icons.backspace_outlined, onTap: _backspace),
                  _key('Done',
                      width: 100, color: AppColors.primary, onTap: _done),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
