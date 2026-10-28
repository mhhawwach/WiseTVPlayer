import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../utils/device_utils.dart';
import 'tv_focus.dart';
import 'tv_keyboard.dart';

/// A search box that adapts to the input device.
///
/// * **On a TV** it is read-only: OK opens the in-app keyboard (results update
///   live as you type) and the arrows always move focus. An *editable* field
///   makes Android attach its system keyboard as soon as the D-pad lands on
///   it, and that keyboard swallows the arrows — the remote got stuck in the
///   Live TV search box until Back was pressed (and a second Back quit the
///   app).
/// * **Elsewhere** it is a normal text field; ↑/↓ still leave it.
class TvSearchField extends StatefulWidget {
  const TvSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.focusNode,
    this.autofocus = false,
    this.decoration = const InputDecoration(),
    this.style,
    this.onSubmitted,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final bool autofocus;
  final InputDecoration decoration;
  final TextStyle? style;

  /// Called after the TV keyboard's Done; defaults to moving focus down to the
  /// results.
  final VoidCallback? onSubmitted;

  @override
  State<TvSearchField> createState() => _TvSearchFieldState();
}

class _TvSearchFieldState extends State<TvSearchField> {
  final _ctrl = TextEditingController();
  late final FocusNode _node = widget.focusNode ?? searchEscapeFocusNode();
  late final bool _ownsNode = widget.focusNode == null;
  bool _isTV = DeviceUtils.isTVSync;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    DeviceUtils.isTV.then((tv) {
      if (mounted && tv != _isTV) setState(() => _isTV = tv);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    if (_ownsNode) _node.dispose();
    super.dispose();
  }

  void _set(String text) {
    _ctrl
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
    widget.onChanged(text);
    if (mounted) setState(() {});
  }

  Future<void> _openKeyboard() async {
    if (_opening) return;
    _opening = true;
    final result = await showTvKeyboard(
      context,
      title: widget.hint,
      initial: _ctrl.text,
      onChanged: _set,
    );
    _opening = false;
    if (result == null || !mounted) return;
    _set(result);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.onSubmitted != null) {
        widget.onSubmitted!();
      } else if (result.isNotEmpty) {
        _node.focusInDirection(TraversalDirection.down);
      }
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (e is KeyDownEvent &&
        (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.gameButtonA)) {
      _openKeyboard();
      return KeyEventResult.handled;
    }
    final TraversalDirection? dir = switch (k) {
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      _ => null,
    };
    if (dir == null) return KeyEventResult.ignored;
    // Unhandled at a page edge, so the shell can still hand Left to the rail.
    return _node.focusInDirection(dir)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final style =
        widget.style ?? const TextStyle(color: AppColors.textPrimary);
    if (!_isTV) {
      return TextField(
        controller: _ctrl,
        focusNode: _node,
        autofocus: widget.autofocus,
        style: style,
        textInputAction: TextInputAction.search,
        onChanged: (v) {
          widget.onChanged(v);
          setState(() {}); // show / hide the clear button
        },
        onSubmitted: (_) => widget.onSubmitted?.call(),
        decoration: widget.decoration.copyWith(
          hintText: widget.hint,
          suffixIcon: _ctrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textMuted),
                  tooltip: 'Clear',
                  onPressed: () => _set(''),
                ),
        ),
      );
    }
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: TextField(
        controller: _ctrl,
        focusNode: _node,
        autofocus: widget.autofocus,
        readOnly: true,
        showCursor: false,
        enableInteractiveSelection: false,
        style: style,
        onTap: _openKeyboard,
        decoration: widget.decoration.copyWith(
          hintText: _ctrl.text.isEmpty ? '${widget.hint} — press OK' : null,
        ),
      ),
    );
  }
}
