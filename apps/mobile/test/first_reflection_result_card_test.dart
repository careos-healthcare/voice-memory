import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/widgets/record/first_reflection_result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('first reflection result card shows signal saved copy and CTAs', (
    tester,
  ) async {
    var recordTapped = false;
    var patternsTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FirstReflectionResultCard(
            onRecordAnother: () => recordTapped = true,
            onViewPatterns: () => patternsTapped = true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(ConsumerUiCopy.firstSignalSavedTitle), findsOneWidget);
    expect(find.text(ConsumerUiCopy.firstSignalSavedBody), findsOneWidget);
    expect(find.text(ConsumerUiCopy.firstSignalSavedSecondary), findsOneWidget);
    expect(find.text(ConsumerUiCopy.postSaveRecordAnother), findsOneWidget);
    expect(find.text(ConsumerUiCopy.viewPatternsCta), findsOneWidget);
    expect(find.textContaining('Anything else connected'), findsNothing);

    await tester.tap(find.text(ConsumerUiCopy.postSaveRecordAnother));
    await tester.tap(find.text(ConsumerUiCopy.viewPatternsCta));
    expect(recordTapped, isTrue);
    expect(patternsTapped, isTrue);
  });
}