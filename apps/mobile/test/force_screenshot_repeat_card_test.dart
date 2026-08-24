import 'dart:io';

import 'package:archiveme_mobile/config/force_screenshot_repeat_card.dart';
import 'package:archiveme_mobile/features/first_session/first_pattern_quality_titles.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/features/archive/screens/archive_belief_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/record/second_session_comparison_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('vm_force_repeat_');
    await AppServices.resetForTest(journalPath: '${tempDir.path}/journal.json');
  });

  tearDown(() {
    ForceScreenshotRepeatCard.testOverride = null;
  });

  group('ForceScreenshotRepeatCard', () {
    test('comparison uses screenshot fallback copy', () {
      final comparison = ForceScreenshotRepeatCard.comparison;
      expect(comparison.title, ConsumerUiCopy.secondSessionPossibleRepeatTitle);
      expect(comparison.body, ConsumerUiCopy.secondSessionSoundsClose);
      expect(
        comparison.whatRepeated,
        ConsumerUiCopy.secondSessionFallbackWhatRepeated,
      );
      expect(
        comparison.whatChanged,
        ConsumerUiCopy.secondSessionFallbackWhatChanged,
      );
      expect(
        comparison.whatToTestNext,
        ConsumerUiCopy.secondSessionFallbackWhatToTestNext,
      );
      expect(comparison.possibleRepeat, isTrue);
      expect(comparison.hasEnoughData, isTrue);
    });
  });

  group('ArchiveBeliefScreen forced repeat card', () {
    testWidgets(
      'shows only SecondSessionComparisonCard when override enabled',
      (tester) async {
        ForceScreenshotRepeatCard.testOverride = true;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: const ArchiveBeliefScreen(),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('force_screenshot_repeat_card_view')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('force_screenshot_repeat_card')),
          findsOneWidget,
        );
        expect(find.byType(SecondSessionComparisonCard), findsOneWidget);
        expect(
          find.text(ConsumerUiCopy.secondSessionPossibleRepeatTitle),
          findsOneWidget,
        );
        expect(
          find.text(ConsumerUiCopy.secondSessionSoundsClose),
          findsOneWidget,
        );
        expect(
          find.text(ConsumerUiCopy.secondSessionFallbackWhatRepeated),
          findsOneWidget,
        );
        expect(
          find.text(ConsumerUiCopy.secondSessionFallbackWhatChanged),
          findsOneWidget,
        );
        expect(
          find.text(ConsumerUiCopy.secondSessionFallbackWhatToTestNext),
          findsOneWidget,
        );
        expect(find.text(ConsumerUiCopy.archiveHomeTitle), findsNothing);
        expect(find.text(FirstPatternQualityTitles.fallback), findsNothing);
        expect(find.text('Your words sound like'), findsNothing);
      },
    );

    testWidgets('override disabled keeps normal archive loading path', (
      tester,
    ) async {
      ForceScreenshotRepeatCard.testOverride = false;

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const ArchiveBeliefScreen()),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('force_screenshot_repeat_card')),
        findsNothing,
      );
    });
  });
}