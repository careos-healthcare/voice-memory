import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/activation/first_three_session_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/widgets/onboarding/first_save_evidence_card.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_empty_view.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_first_archive_view.dart';
import 'package:voicememory_mobile/widgets/record/record_top_archive_promise_hero.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

void main() {
  group('Visible archive proof UI', () {
    test('first save copy is cautious and does not claim a pattern', () {
      expect(
        FirstThreeSessionCopy.session1Title,
        VisibleArchiveProofCopy.firstSaveTitle,
      );
      expect(
        FirstThreeSessionCopy.session1Body,
        contains('first piece of evidence'),
      );
      expect(
        FirstThreeSessionCopy.session1EnoughForToday,
        contains('No conclusion yet'),
      );
      expect(
        FirstThreeSessionCopy.session1Title.toLowerCase(),
        isNot(contains('pattern found')),
      );
    });

    testWidgets('zero entries Record hero renders product promise copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: RecordTopArchivePromiseHero()),
        ),
      );

      expect(
        find.byKey(const Key('record_top_archive_promise_hero')),
        findsOneWidget,
      );
      expect(find.text(VisibleArchiveProofCopy.recordHeroTitle), findsOneWidget);
      expect(find.text(VisibleArchiveProofCopy.recordHeroBody), findsOneWidget);
      expect(find.text(VisibleArchiveProofCopy.recordHeroChipReturned), findsOneWidget);
      expect(find.text(VisibleArchiveProofCopy.recordHeroChipSoftened), findsOneWidget);
      expect(find.text(VisibleArchiveProofCopy.recordHeroChipChanged), findsOneWidget);
      expect(find.textContaining('pattern found'), findsNothing);
    });

    testWidgets('first save card shows archive started copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstSaveEvidenceCard(
              onViewArchive: () {},
              onRecordAnother: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('first_save_archive_started_card')), findsOneWidget);
      expect(find.text(VisibleArchiveProofCopy.firstSaveTitle), findsOneWidget);
      expect(find.text(VisibleArchiveProofCopy.firstSaveBody), findsOneWidget);
      expect(find.text(VisibleArchiveProofCopy.firstSaveSecondary), findsOneWidget);
      expect(find.text(VisibleArchiveProofCopy.firstSavePrimaryCta), findsOneWidget);
      expect(find.text(VisibleArchiveProofCopy.firstSaveViewArchiveCta), findsOneWidget);
      expect(find.textContaining('pattern found'), findsNothing);
    });

    testWidgets('patterns zero-entry shows preview without conclusion', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PatternsEmptyView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('patterns_empty_archive_preview_card')),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.patternsEmptyPreviewTitle),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.patternsEmptyPreviewBeliefRow),
        findsOneWidget,
      );
      expect(find.textContaining('Not enough evidence yet'), findsOneWidget);
      expect(find.textContaining('pattern found'), findsNothing);
    });

    testWidgets('patterns one-entry shows evidence line and add another CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PatternsFirstArchiveView(
              savedEntryId: 'e1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('patterns_one_entry_archive_preview_card')),
        findsOneWidget,
      );
      expect(
        find.text(ConsumerUiCopy.patternsFirstEntrySavedTitle),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.patternsOneEntryEvidenceRow),
        findsOneWidget,
      );
      expect(find.text(VisibleArchiveProofCopy.patternsOneEntryCta), findsOneWidget);
      expect(find.textContaining('pattern found'), findsNothing);
    });
  });
}
