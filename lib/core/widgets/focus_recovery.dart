import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../utils/device_utils.dart';

/// Restores D-pad focus when it is lost, so the on-screen highlight never just
/// "disappears" on a TV (forcing several blind presses to get it back).
///
/// Focus gets lost whenever the widget that currently holds it is disposed or
/// rebuilt out from under the focus system — list/grid recycling, a content
/// refresh, an async provider update, switching tabs, etc. When that happens
/// Flutter drops the primary focus onto a [FocusScopeNode] (or null), and the
/// next directional key presses are spent re-entering a scope instead of moving
/// the selection — which is exactly the "highlight faded, press it a bunch of
/// times" symptom.
///
/// This widget listens to the global [FocusManager] and, **on TV only**:
///   1. remembers the last *concrete* focused node (a leaf, not a scope);
///   2. when focus falls to a scope/null and is still lost after the frame
///      settles, re-focuses that node if it's still alive, otherwise the first
///      focusable in the scope that now holds focus.
///
/// It is intentionally inert on phones/tablets, where "nothing focused" is the
/// normal resting state and forcing focus would pop keyboards / show stray
/// highlights.
class FocusRecovery extends StatefulWidget {
  const FocusRecovery({super.key, required this.child});

  final Widget child;

  @override
  State<FocusRecovery> createState() => _FocusRecoveryState();
}

class _FocusRecoveryState extends State<FocusRecovery> {
  FocusNode? _lastGood;
  bool _isTV = false;
  bool _dpadSeen = false;
  bool _scheduled = false;

  // Active on a detected TV, OR as soon as the user presses a D-pad/remote key
  // (covers boxes where the native leanback `isTV` check returns false). Stays
  // inert on pure-touch phones, where forcing focus would be wrong.
  // Off on web (webOS): the aggressive auto-refocus watchdog was implicated in a
  // main-thread stall on the TV, and the HTML-renderer build navigates fine on
  // the framework's native directional focus. (Re-enable + re-test on the TV if
  // focus-loss turns out to be an issue on webOS.)
  bool get _active => (_isTV || _dpadSeen) && !kIsWeb;

  @override
  void initState() {
    super.initState();
    DeviceUtils.isTV.then((tv) {
      if (mounted) _isTV = tv;
    });
    HardwareKeyboard.instance.addHandler(_onKey);
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  // Never consumes the event (returns false) — just notes that a remote/D-pad
  // is in use so the watchdog activates even when `isTV` is unreliable.
  bool _onKey(KeyEvent event) {
    if (!_dpadSeen && event is KeyDownEvent) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.arrowUp ||
          k == LogicalKeyboardKey.arrowDown ||
          k == LogicalKeyboardKey.arrowLeft ||
          k == LogicalKeyboardKey.arrowRight ||
          k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.gameButtonA) {
        _dpadSeen = true;
      }
    }
    return false;
  }

  static bool _isConcrete(FocusNode? n) =>
      n != null &&
      n is! FocusScopeNode &&
      n.context != null &&
      n.canRequestFocus;

  void _onFocusChanged() {
    if (!_active) return;
    final pf = FocusManager.instance.primaryFocus;
    if (_isConcrete(pf)) {
      _lastGood = pf;
      return;
    }
    // Focus is resting on a scope / null — possibly a transient state during a
    // legitimate navigation. Re-check after the frame settles; only step in if
    // it's still lost (so we never fight a real transition that's about to set
    // focus itself, e.g. a new screen's autofocus).
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !_active) return;
      final cur = FocusManager.instance.primaryFocus;
      if (_isConcrete(cur)) return; // recovered on its own

      // 1) Re-focus the last concrete node if it survived.
      final lg = _lastGood;
      if (_isConcrete(lg)) {
        lg!.requestFocus();
        return;
      }
      // 2) Otherwise focus the first focusable in the scope that holds focus.
      final scope = cur is FocusScopeNode ? cur : FocusManager.instance.rootScope;
      for (final node in scope.traversalDescendants) {
        if (node.canRequestFocus && !node.skipTraversal && node.context != null) {
          node.requestFocus();
          return;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Drives **directional focus** from arrow keys on the **web build (webOS)**.
///
/// On the webOS HTML renderer the framework's default arrow-key → directional
/// traversal does not reliably fire, so the remote D-pad couldn't move the
/// selection (only the cursor worked). This widget sits just below MaterialApp's
/// default `Shortcuts`; because key events bubble from the focused leaf upward,
/// it only runs **after** the focused widget ignored the key — so the side
/// rail's own Left/Right bridging and OK/Select handlers (deeper in the tree)
/// still take precedence. For a plain arrow that nothing else handled, it calls
/// `focusInDirection`, which is exactly what the default traversal would have
/// done. Inert (pass-through) off the web.
class WebDirectionalFocus extends StatelessWidget {
  const WebDirectionalFocus({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: child,
    );
  }

  static KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final TraversalDirection? dir = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      _ => null,
    };
    if (dir == null) return KeyEventResult.ignored;
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return KeyEventResult.ignored;
    final moved = primary.focusInDirection(dir);
    // If we couldn't move (edge of a scope), let it bubble so the default
    // Shortcuts/cross-scope handlers still get a chance.
    return moved ? KeyEventResult.handled : KeyEventResult.ignored;
  }
}
