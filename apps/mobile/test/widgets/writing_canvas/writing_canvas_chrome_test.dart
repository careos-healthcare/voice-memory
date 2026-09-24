import 'package:archiveme_mobile/widgets/writing_canvas/writing_canvas_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('typing hides chrome; idle and scroll-up restore it', () {
    final chrome = WritingCanvasChromeController(
      idleRestore: const Duration(hours: 1),
    );

    expect(chrome.isChromeVisible, isTrue);
    chrome.onTyped(hasText: true, focused: true);
    expect(chrome.isChromeVisible, isFalse);

    chrome.onScrollDelta(-12);
    expect(chrome.isChromeVisible, isTrue);

    chrome.onTyped(hasText: true, focused: true);
    expect(chrome.isChromeVisible, isFalse);
    chrome.restoreChrome();
    expect(chrome.isChromeVisible, isTrue);

    chrome.onTyped(hasText: false, focused: false);
    expect(chrome.isChromeVisible, isTrue);
    chrome.dispose();
  });

  testWidgets('fade widget hides child when chrome is off', (tester) async {
    final chrome = WritingCanvasChromeController(
      idleRestore: const Duration(hours: 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WritingCanvasChromeFade(
            controller: chrome,
            child: const Text('stats'),
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const Key('writing_canvas_chrome_fade')),
          )
          .opacity,
      1,
    );

    chrome.onTyped(hasText: true, focused: true);
    await tester.pump();
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const Key('writing_canvas_chrome_fade')),
          )
          .opacity,
      0,
    );
    chrome.dispose();
  });
}
