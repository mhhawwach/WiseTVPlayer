import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A D-pad-friendly text field for Android TV / remotes.
///
/// A normal autofocused or traversed `TextField` pops the on-screen keyboard the
/// instant it gains focus. On many TV boxes that traps the user — the keyboard
/// fights focus traversal and the D-pad can't cleanly get back out (you can't
/// even reach the keys). This field stays **read-only** (no keyboard) while the
/// D-pad is merely moving over it; press **OK / Select** to start typing (the
/// keyboard opens), and the keyboard's Done — or moving focus away — stops
/// editing. So you can freely D-pad between fields, and only summon the keyboard
/// when you actually mean to type.
class TvTextField extends StatefulWidget {
  const TvTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.focusNode,
    this.autofocus = false,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;
  final String? Function(String?)? validator;

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  late final FocusNode _node = widget.focusNode ?? FocusNode();
  bool _ownsNode = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ownsNode = widget.focusNode == null;
    _node.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    // Focus left the field (Back closed the keyboard, or the D-pad moved away)
    // → drop out of editing so the next OK re-opens the keyboard cleanly.
    if (!_node.hasFocus && _editing && mounted) setState(() => _editing = false);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    if (_ownsNode) _node.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (!_editing &&
        (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.gameButtonA)) {
      // The field is already focused; flipping readOnly → false on a focused
      // field makes Flutter open the keyboard. User-initiated (not at screen
      // entry), so it opens in a navigable state.
      setState(() => _editing = true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // canRequestFocus:false + skipTraversal so this wrapper never competes for
    // focus; it only catches OK bubbling up from the focused field.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _node,
        autofocus: widget.autofocus,
        readOnly: !_editing,
        obscureText: widget.obscure,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: (_) {
          setState(() => _editing = false);
          widget.onSubmitted?.call();
        },
        onTapOutside: (_) {
          if (_editing) setState(() => _editing = false);
        },
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: widget.label,
          // When idle, prompt the user to press OK; while editing, show the
          // real hint.
          hintText: _editing ? widget.hint : 'Press OK to type',
          prefixIcon: widget.icon != null
              ? Icon(widget.icon, color: AppColors.textMuted)
              : null,
          suffixIcon: _editing
              ? Icon(Icons.keyboard_rounded,
                  size: 18, color: AppColors.primary)
              : null,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
        ),
        validator: widget.validator,
      ),
    );
  }
}
