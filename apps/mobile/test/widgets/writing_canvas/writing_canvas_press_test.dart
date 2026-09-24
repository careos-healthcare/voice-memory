import 'package:archiveme_mobile/widgets/writing_canvas/writing_canvas_press.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('primary wrap fires a light impact then the action', (
    tester,
  ) async {
    final haptics = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        haptics.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    var pressed = 0;
    final wrapped = WritingCanvasPress.wrap(() => pressed++);
    wrapped!();

    expect(pressed, 1);
    expect(
      haptics.any((call) => call.method == 'HapticFeedback.vibrate'),
      isTrue,
    );
  });

  testWidgets('spring host scales on pointer down', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WritingCanvasSpringHost(
            child: SizedBox(width: 80, height: 40, child: Text('Save')),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Save')),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(Transform), findsWidgets);
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
