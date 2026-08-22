import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/widgets/record/first_recording_handoff_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'first-run handoff card shows focused copy and starts recording',
    (tester) async {
      var started = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstRecordingHandoffCard(
              onStartRecording: () => started = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(ConsumerUiCopy.firstRecordingHandoffTitle),
        findsOneWidget,
      );
      expect(
        find.text(ConsumerUiCopy.firstRecordingHandoffBody),
        findsOneWidget,
      );
      expect(
        find.text(ConsumerUiCopy.firstRecordingHandoffCta),
        findsOneWidget,
      );
      expect(find.text(ConsumerUiCopy.patternsEmptyCta), findsNothing);

      await tester.tap(find.text(ConsumerUiCopy.firstRecordingHandoffCta));
      await tester.pumpAndSettle();
      expect(started, isTrue);
    },
  );
}