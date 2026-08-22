import 'package:archiveme_mobile/features/onboarding/record_return_pro_state.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/capture_entry_actions.dart';
import 'package:archiveme_mobile/widgets/onboarding/record_once_intro_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('First impression clarity', () {
    test('record once copy is exact', () {
      expect(RecordReturnProCopy.recordOnceCta, 'Record one moment');
      expect(
        RecordReturnProCopy.recordOnceSupporting,
        'Save small moments when something stands out — in your own words.',
      );
    });

    testWidgets('intro card renders exact copy without blocking layout', (
      tester,
    ) async {
      var recorded = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                RecordOnceIntroCard(onRecord: () => recorded = true),
                CaptureEntryActions(onRecord: () {}),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('record_once_intro_card')), findsOneWidget);
      expect(
        find.text(RecordReturnProCopy.recordOnceSupporting),
        findsOneWidget,
      );
      expect(find.text(RecordReturnProCopy.recordOnceCta), findsOneWidget);
      expect(find.byType(CaptureEntryActions), findsOneWidget);

      await tester.tap(find.byKey(const Key('record_once_cta')));
      await tester.pump();
      expect(recorded, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}