import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisetv_player/core/widgets/tv_keyboard.dart';
import 'package:wisetv_player/features/parental/pin_pad.dart';

void main() {
  group('TV keyboard (D-pad grid)', () {
    late String? result;

    Future<void> open(WidgetTester tester) async {
      result = null;
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showTvKeyboard(context, title: 'T', initial: ''),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> press(WidgetTester tester, LogicalKeyboardKey key,
        [int times = 1]) async {
      for (var i = 0; i < times; i++) {
        await tester.sendKeyEvent(key);
        await tester.pump();
      }
    }

    testWidgets('arrows stay on the row and Down picks the nearest key',
        (tester) async {
      await open(tester); // focus starts on "q"
      await press(tester, LogicalKeyboardKey.arrowDown); // "a"
      await press(tester, LogicalKeyboardKey.arrowLeft); // stays on "a"
      await press(tester, LogicalKeyboardKey.enter);
      await press(tester, LogicalKeyboardKey.arrowRight, 8); // "l"
      await press(tester, LogicalKeyboardKey.arrowDown); // "m", not a row below
      await press(tester, LogicalKeyboardKey.enter);
      // Down twice to the control row, then far right to Done (and no further).
      await press(tester, LogicalKeyboardKey.arrowDown, 2);
      await press(tester, LogicalKeyboardKey.arrowRight, 6);
      await press(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(result, 'am');
    });

    testWidgets('a hardware keyboard types straight in', (tester) async {
      await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await press(tester, LogicalKeyboardKey.arrowDown, 5); // control row
      await press(tester, LogicalKeyboardKey.arrowRight, 6); // Done
      await press(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(result, 'x');
    });
  });

  group('PIN pad', () {
    testWidgets('D-pad and digit keys both enter digits', (tester) async {
      final keys = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: PinHardwareKeys(
              onKey: keys.add,
              child: PinNumPad(onKey: keys.add),
            ),
          ),
        ),
      ));
      await tester.pump();
      // "5" has initial focus; OK presses it, Up moves to "2".
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      // A remote with number keys.
      await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      expect(keys, ['5', '2', '7', pinBackspace]);
    });
  });
}
