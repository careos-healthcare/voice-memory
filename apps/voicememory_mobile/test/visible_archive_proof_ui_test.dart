import 'package:voicememory_mobile/features/activation/first_three_journey_engine.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/activation/first_three_session_copy.dart';
import 'package:voicememory_mobile/features/archive_tab/archive_tab_four_state_copy.dart';
import 'package:voicememory_mobile/widgets/onboarding/first_save_evidence_card.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_empty_view.dart';
import 'package:voicememory_mobile/widgets/record/record_top_archive_promise_hero.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

void main() {
  group('Visible archive proof UI', () {
    test('first-run promise uses three scannable steps', () {
      expect(VisibleArchiveProofCopy.firstRunPromiseSteps, [
        'When it repeats, save it.',
        'Save one real moment. ArchiveMe compares it later.',
        'Not a diary. Not homework. One sentence is enough.',
      ]);
    });

    test('first save copy is cautious and does not claim a pattern', () {
      expect(
        FirstThreeSessionCopy.session1Title,
        VisibleArchiveProofCopy.firstSavePostSaveTitle,
      );
      expect(FirstThreeSessionCopy.session1Body, contains('shows up again'));
      expect(
        FirstThreeSessionCopy.session1EnoughForToday,
        VisibleArchiveProofCopy.firstSavePostSaveReassurance,
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
      expect(find.text(VisibleArchiveProofCopy.recordHeroTitle), findsNothing);
      for (final step in VisibleArchiveProofCopy.firstRunPromiseSteps) {
        expect(find.text(step), findsOneWidget);
      }
      expect(
        find.text(VisibleArchiveProofCopy.firstRunBeliefsNotConclusionsLine),
        findsNothing,
      );
      expect(find.textContaining('pattern found'), findsNothing);
    });

    testWidgets('first save card shows archive started copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstSaveEvidenceCard(
              onViewArchive: () {},
              onRecordAnother: () {},
              onDoneForToday: () {},
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('first_save_archive_started_card')),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.firstSavePostSaveTitle),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.firstSavePostSaveBody),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.firstSavePostSaveReassurance),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.firstSavePrimaryCta),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.firstSaveViewArchiveCta),
        findsOneWidget,
      );
      expect(find.textContaining('pattern found'), findsNothing);
    });

    testWidgets(
      'patterns zero-entry shows the shared archive empty-state card, no belief rows',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: PatternsEmptyView())),
        );
        await tester.pumpAndSettle();

        // Patterns' zero-entry state now delegates to the same canonical
        // ArchiveTabEntryStateCard used by Archive Home and the Changes tab
        // (see ARCHIVE_SCREEN_SPEC_V1.md) rather than its own mind-map copy.
        expect(
          find.byKey(const Key('archive_tab_entry_state_empty')),
          findsOneWidget,
        );
        expect(find.text(ArchiveTabFourStateCopy.emptyBody), findsOneWidget);
        expect(find.text('Current belief'), findsNothing);
        expect(find.textContaining('Not enough evidence yet'), findsNothing);
        expect(find.textContaining('pattern found'), findsNothing);
      },
    );

    test('early two-entry journey uses comparison payoff copy', () {
      expect(
        const FirstThreeJourneyEngine().build(reflectionCount: 2).title,
        VisibleArchiveProofCopy.twoEntryCompareTitle,
      );
      expect(
        const FirstThreeJourneyEngine().build(reflectionCount: 2).body,
        contains('No clear repeat yet'),
      );
    });
  });
}
