import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../utils/device_utils.dart';
import 'tv_keyboard.dart';

/// A text field that adapts to the input device:
///
/// * **On a TV** (D-pad remote) the system on-screen keyboard often won't hand
///   the arrows to its keys, so typing is impossible. Here the field is
///   read-only and pressing **OK** opens an in-app, fully D-pad-navigable
///   keyboard ([showTvKeyboard]).
/// * **On desktop / phone** it's a normal editable [TextFormField] — click and
///   type with the hardware or system keyboard, exactly as before.
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
  bool _isTV = DeviceUtils.isTVSync;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _ownsNode = widget.focusNode == null;
    // Correct the TV flag once the (cached) async check resolves.
    DeviceUtils.isTV.then((tv) {
      if (mounted && tv != _isTV) setState(() => _isTV = tv);
    });
  }

  @override
  void dispose() {
    if (_ownsNode) _node.dispose();
    super.dispose();
  }

  Future<void> _openKeyboard() async {
    if (_opening) return;
    _opening = true;
    final result = await showTvKeyboard(
      context,
      title: widget.label,
      initial: widget.controller.text,
    );
    _opening = false;
    if (result != null && mounted) {
      widget.controller
        ..text = result
        ..selection = TextSelection.collapsed(offset: result.length);
      setState(() {}); // refresh the on-field display
      widget.onSubmitted?.call(); // advance to the next field (or submit)
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (e is KeyDownEvent &&
        (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.gameButtonA)) {
      _openKeyboard();
      return KeyEventResult.handled;
    }
    // Even read-only, the editor swallows arrows (selection movement) via the
    // root text-editing shortcuts — which trapped the D-pad on the field (the
    // "can't reach the next field / Save button" bug). Move focus instead.
    final TraversalDirection? dir = switch (k) {
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      _ => null,
    };
    if (dir != null) {
      FocusManager.instance.primaryFocus?.focusInDirection(dir);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  InputDecoration _decoration({String? hintText}) => InputDecoration(
        labelText: widget.label,
        hintText: hintText,
        prefixIcon: widget.icon != null
            ? Icon(widget.icon, color: AppColors.textMuted)
            : null,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      );

  @override
  Widget build(BuildContext context) {
    if (!_isTV) {
      // Desktop / phone — normal editable field (system / hardware keyboard).
      return TextFormField(
        controller: widget.controller,
        focusNode: _node,
        autofocus: widget.autofocus,
        obscureText: widget.obscure,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: (_) => widget.onSubmitted?.call(),
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: _decoration(hintText: widget.hint),
        validator: widget.validator,
      );
    }

    // TV — read-only; OK (or tap) opens the in-app keyboard.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _node,
        autofocus: widget.autofocus,
        readOnly: true,
        showCursor: false,
        obscureText: widget.obscure,
        onTap: _openKeyboard,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: _decoration(hintText: 'Press OK to type'),
        validator: widget.validator,
      ),
    );
  }
}
