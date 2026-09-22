import 'package:archiveme_mobile/features/archive_theory/archive_theory_models.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_display_titles.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_theory_hero_card.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_v1_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('display titles leave storage keys unchanged', () {
    expect(ArchiveDomainKey.theories.storageKey, 'theories');
    expect(ArchiveDomainKey.theories.displayTitle, 'Life Patterns');
    expect(ArchiveDomainKey.factLedger.storageKey, 'fact_ledger');
    expect(ArchiveDomainKey.factLedger.displayTitle, 'Core Memory');
    expect(
      ArchiveDomainKey.theoryRankingEngine.storageKey,
      'theory_ranking_engine',
    );
    expect(ArchiveDomainKey.theoryRankingEngine.displayTitle, 'Key Themes');
    expect(ArchiveDomainKey.traitPollution.storageKey, 'trait_pollution');
    expect(
      ArchiveDomainKey.traitPollution.displayTitle,
      'Pattern Disambiguation',
    );
  });

  testWidgets('hero card fits a phone and hides scores until expanded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const statement =
        'You return to the same worry after late meetings, then talk '
        'yourself out of it before morning, and the loop starts again '
        'the next time the calendar fills up past dinner.';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ArchiveTheoryHeroCard(
              theory: ArchiveCurrentTheory(
                statement: statement,
                confidencePercent: 72,
                evidenceCount: 4,
                counterEvidenceCount: 1,
                lastUpdated: DateTime(2026, 6, 2),
                isConfident: true,
                missingEvidenceMessage: 'Need a calmer week.',
                strengthenEvidenceLines: const [
                  'Name the meeting that set it off',
                  'Note what changed the next morning',
                  'A third line that stays out of the summary',
                ],
              ),
              onShowMeWhy: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Life Patterns'), findsOneWidget);
    expect(find.text('Steady'), findsOneWidget);
    expect(find.text('Name the meeting that set it off'), findsOneWidget);
    expect(find.text('Note what changed the next morning'), findsOneWidget);
    expect(
      find.text('A third line that stays out of the summary'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);

    final score = find.textContaining('72%');
    if (score.evaluate().isNotEmpty) {
      expect(tester.getSize(score).height, 0);
    }

    await tester.tap(find.text('Technical Reasoning'));
    await tester.pumpAndSettle();
    expect(find.textContaining('72%'), findsOneWidget);
    expect(tester.getSize(find.textContaining('72%')).height, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick check-in selects an anchor in one tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: QuickCheckInBar()),
      ),
    );

    await tester.tap(find.byKey(const Key('quick_check_in_grounded')));
    await tester.pump();

    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('quick_check_in_grounded')))
          .selected,
      isTrue,
    );
    expect(find.text('Overwhelmed'), findsOneWidget);
    expect(find.text('Reflective'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
