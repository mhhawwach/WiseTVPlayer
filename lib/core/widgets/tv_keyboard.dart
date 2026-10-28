import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'focusable_card.dart';

/// A fully D-pad-navigable on-screen keyboard for TVs whose system IME doesn't
/// hand the remote's arrows to the keyboard (so typing was impossible). Each key
/// is a focusable cell; OK presses it. A physical/USB keyboard also works — its
/// keystrokes are captured into the field.
///
/// [onChanged] fires on every edit (live search); the result is the entered
/// text on "Done", or null if dismissed (Back).
Future<String?> showTvKeyboard(
  BuildContext context, {
  required String title,
  required String initial,
  ValueChanged<String>? onChanged,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _TvKeyboardSheet(
      title: title,
      initial: initial,
      onChanged: onChanged,
    ),
  );
}

class _TvKeyboardSheet extends StatefulWidget {
  const _TvKeyboardSheet({
    required this.title,
    required this.initial,
    this.onChanged,
  });
  final String title;
  final String initial;
  final ValueChanged<String>? onChanged;

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
  static const _controlKeys = 4; // Caps, Space, Backspace, Done

  // One node per key, row by row (the control row last). Arrow keys move on
  // this grid explicitly: the rows have different widths and offsets, so the
  // framework's geometric guess jumped rows (Left from "a" went up to "q",
  // Down from "l" skipped a row, Right from Done went up to "=").
  late final List<List<FocusNode>> _grid = [
    for (final row in _rows)
      [for (var i = 0; i < row.length; i++) FocusNode()],
    [for (var i = 0; i < _controlKeys; i++) FocusNode()],
  ];

  @override
  void dispose() {
    for (final row in _grid) {
      for (final node in row) {
        node.dispose();
      }
    }
    super.dispose();
  }

  void _setText(String text) {
    setState(() => _text = text);
    widget.onChanged?.call(text);
  }

  void _type(String ch) => _setText(_text + (_shift ? ch.toUpperCase() : ch));

  void _backspace() {
    if (_text.isNotEmpty) _setText(_text.substring(0, _text.length - 1));
  }

  void _done() => Navigator.of(context).pop(_text);

  bool _move(LogicalKeyboardKey key) {
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null) return false;
    for (var r = 0; r < _grid.length; r++) {
      final c = _grid[r].indexOf(focused);
      if (c < 0) continue;
      FocusNode? target;
      if (key == LogicalKeyboardKey.arrowLeft && c > 0) {
        target = _grid[r][c - 1];
      } else if (key == LogicalKeyboardKey.arrowRight &&
          c < _grid[r].length - 1) {
        target = _grid[r][c + 1];
      } else if (key == LogicalKeyboardKey.arrowUp && r > 0) {
        target = _nearestInRow(r - 1, focused);
      } else if (key == LogicalKeyboardKey.arrowDown && r < _grid.length - 1) {
        target = _nearestInRow(r + 1, focused);
      }
      target?.requestFocus();
      return true; // at an edge the highlight simply stays put
    }
    return false;
  }

  FocusNode _nearestInRow(int row, FocusNode from) {
    final x = from.rect.center.dx;
    return _grid[row].reduce((a, b) =>
        (a.rect.center.dx - x).abs() <= (b.rect.center.dx - x).abs() ? a : b);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.arrowDown) {
      return _move(k) ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    // Capture a physical / USB keyboard so users with one can just type.
    if (k == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    final ch = e.character;
    if (ch != null && ch.length == 1 && ch.codeUnitAt(0) >= 32) {
      _setText(_text + ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _key(
    String label, {
    required FocusNode node,
    required VoidCallback onTap,
    bool autofocus = false,
    double width = 46,
    Color? color,
    IconData? icon,
    String? semanticLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: FocusableCard(
        focusNode: node,
        autofocus: autofocus,
        borderRadius: 8,
        onPressed: onTap,
        semanticLabel: semanticLabel,
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
    final controls = _grid.last;
    // canRequestFocus/skipTraversal: this wrapper only LISTENS for bubbled
    // keys — it must never hold D-pad focus itself. Without these flags it is
    // an invisible, sheet-sized focusable: directional traversal could land on
    // it (observed around the middle of the QWERTY row on Fire TV), the
    // highlight vanished, and — because every key lies inside its rect — no
    // arrow direction could ever escape it again.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
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
                    for (var c = 0; c < _rows[r].length; c++)
                      _key(
                          _shift
                              ? _rows[r][c].toUpperCase()
                              : _rows[r][c],
                          node: _grid[r][c],
                          autofocus: r == 1 && c == 0, // "q"
                          onTap: () => _type(_rows[r][c])),
                  ],
                ),
              // Control row.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _key('',
                      node: controls[0],
                      icon: Icons.keyboard_capslock_rounded,
                      semanticLabel: _shift ? 'Caps lock on' : 'Caps lock',
                      color: _shift ? AppColors.primary : null,
                      onTap: () => setState(() => _shift = !_shift)),
                  _key('Space',
                      node: controls[1],
                      width: 220,
                      onTap: () => _setText('$_text ')),
                  _key('',
                      node: controls[2],
                      icon: Icons.backspace_outlined,
                      semanticLabel: 'Backspace',
                      onTap: _backspace),
                  _key('Done',
                      node: controls[3],
                      width: 100,
                      color: AppColors.primary,
                      onTap: _done),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
