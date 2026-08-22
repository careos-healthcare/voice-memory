import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_personal_evidence_summary_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_personal_evidence_summary_model.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/pressure_personal_evidence_summary_card.dart';
import 'package:archiveme_research/screens/pressure_insights_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PressureCheckInRecord _record({
  required String id,
  int daysAgo = 0,
  String optionId = 'could_not_stop',
  List<String> contextIds = const [],
  String? fear,
  String? stopCostNote,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: DateTime(2026, 6, 9, 12).subtract(Duration(days: daysAgo)),
    optionId: optionId,
    contextIds: contextIds,
    fear: fear,
    stopCostNote: stopCostNote,
    transcript: 'pressure moment',
  );
}

/// Four entries with rich repetition: work context x3, evening x2,
/// "deadline" written twice, dominant option `could_not_stop` x3.
List<PressureCheckInRecord> _richRecords() => [
  _record(
    id: 'a',
    daysAgo: 3,
    contextIds: const ['work', 'evening'],
    fear: 'Missing the deadline',
  ),
  _record(
    id: 'b',
    daysAgo: 2,
    contextIds: const ['work'],
    fear: 'The deadline slipping',
  ),
  _record(id: 'c', daysAgo: 1, contextIds: const ['work', 'evening']),
  _record(id: 'd', optionId: 'guilty_resting'),
];

void main() {
  const engine = PressurePersonalEvidenceSummaryEngine();

  group('Personal evidence engine', () {
    test('no summary before 3 entries', () {
      final summary = engine.build([
        _record(id: 'a', daysAgo: 1, contextIds: const ['work']),
        _record(id: 'b', contextIds: const ['work']),
      ]);
      expect(summary.hasSummary, isFalse);
      expect(summary.reasonLine, isNull);
      expect(summary.evidenceTerms, isEmpty);
    });

    test('summary appears at 3+ entries with repetition', () {
      final summary = engine.build(_richRecords());
      expect(summary.hasSummary, isTrue);
      expect(summary.entryCount, 4);
      expect(summary.reasonLine, isNotNull);
      expect(summary.confidenceLabel, isNotNull);
      expect(
        PressurePersonalEvidenceSummary.headline,
        'Why this may be your pattern',
      );
    });

    test('repeated terms are extracted, user words before contexts', () {
      final summary = engine.build(_richRecords());
      // "deadline" was written by the user in 2 entries; work context x3.
      expect(summary.evidenceTerms, contains('deadline'));
      expect(summary.evidenceTerms, contains('work'));
      expect(
        summary.evidenceTerms.indexOf('deadline'),
        lessThan(summary.evidenceTerms.indexOf('work')),
      );
      expect(
        summary.evidenceTerms.length,
        lessThanOrEqualTo(PressurePersonalEvidenceSummaryEngine.maxTerms),
      );
      expect(summary.reasonLine, contains('deadline'));
      expect(summary.reasonLine, contains('4 moments'));
    });

    test('nothing repeated yields no summary', () {
      // Three entries, all different options, no contexts, no notes.
      final summary = engine.build([
        _record(id: 'a', daysAgo: 2),
        _record(id: 'b', daysAgo: 1, optionId: 'guilty_resting'),
        _record(id: 'c', optionId: 'had_to_prove_enough'),
      ]);
      expect(summary.hasSummary, isFalse);
    });

    test('weak evidence gets a cautious line, never overclaims', () {
      // Repeated option but no contexts and no user-written terms.
      final summary = engine.build([
        for (var i = 0; i < 3; i++) _record(id: 'w$i', daysAgo: i),
      ]);
      expect(summary.hasSummary, isTrue);
      // Option theme alone still names what repeated.
      expect(summary.evidenceTerms, ['stopping']);

      final noTermsSummary = engine.build([
        _record(id: 'x0', daysAgo: 2),
        _record(id: 'x1', daysAgo: 1),
        _record(id: 'x2', optionId: 'guilty_resting'),
      ]);
      expect(noTermsSummary.hasSummary, isTrue);

      for (final s in [summary, noTermsSummary]) {
        final copy = '${s.reasonLine} ${s.confidenceLabel}'.toLowerCase();
        for (final overclaim in const [
          'always',
          'proven',
          'definitely',
          'certain',
          'guaranteed',
          'every time',
          'diagnos',
          'disorder',
        ]) {
          expect(
            copy,
            isNot(contains(overclaim)),
            reason: 'copy must not contain "$overclaim"',
          );
        }
      }
    });

    test('generic app words are never used as evidence terms', () {
      final summary = engine.build([
        _record(id: 'g0', daysAgo: 2, fear: 'The pressure of this moment'),
        _record(id: 'g1', daysAgo: 1, fear: 'The pressure of this moment'),
        _record(id: 'g2'),
      ]);
      expect(summary.evidenceTerms, isNot(contains('pressure')));
      expect(summary.evidenceTerms, isNot(contains('moment')));
      expect(summary.evidenceTerms, isNot(contains('the')));
    });

    test('confidence labels change with entry count and repetition', () {
      // 3 entries, top repeat 2 → early signal.
      final early = engine.build([
        _record(id: 'e0', daysAgo: 2),
        _record(id: 'e1', daysAgo: 1),
        _record(id: 'e2', optionId: 'guilty_resting'),
      ]);
      expect(
        early.confidenceLabel,
        PressurePersonalEvidenceSummary.earlySignalLabel,
      );

      // 4 entries, top repeat 3 → repeated signal.
      final repeated = engine.build([
        for (var i = 0; i < 3; i++) _record(id: 'r$i', daysAgo: i),
        _record(id: 'r3', daysAgo: 3, optionId: 'guilty_resting'),
      ]);
      expect(
        repeated.confidenceLabel,
        PressurePersonalEvidenceSummary.repeatedSignalLabel,
      );

      // 6 entries, top repeat 5 → strong repeated signal.
      final strong = engine.build([
        for (var i = 0; i < 5; i++) _record(id: 's$i', daysAgo: i),
        _record(id: 's5', daysAgo: 5, optionId: 'guilty_resting'),
      ]);
      expect(
        strong.confidenceLabel,
        PressurePersonalEvidenceSummary.strongRepeatedSignalLabel,
      );
    });
  });

  group('Personal evidence card', () {
    testWidgets('renders reason line, chips, confidence, and entry count', (
      tester,
    ) async {
      final summary = engine.build(_richRecords());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PressurePersonalEvidenceSummaryCard(summary: summary),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Why this may be your pattern'), findsOneWidget);
      expect(find.text(summary.reasonLine!), findsOneWidget);
      for (final term in summary.evidenceTerms) {
        expect(find.text(term), findsOneWidget);
      }
      expect(
        find.byKey(const Key('pressure_personal_evidence_confidence')),
        findsOneWidget,
      );
      expect(find.text(summary.confidenceLabel!), findsOneWidget);
      expect(find.text('4 pressure moments so far'), findsOneWidget);
    });

    testWidgets('renders nothing without a summary', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PressurePersonalEvidenceSummaryCard(
              summary: PressurePersonalEvidenceSummary.insufficient(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('pressure_personal_evidence_card')),
        findsNothing,
      );
    });
  });

  group('Pressure Insights integration', () {
    testWidgets('shows the evidence card above the pattern reveal', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 4200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: false),
            records: _richRecords(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(
        const Key('pressure_personal_evidence_card'),
      );
      expect(cardFinder, findsOneWidget);
      expect(
        find.byKey(const Key('pressure_pattern_reveal_card')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(cardFinder).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const Key('pressure_pattern_reveal_card')))
              .dy,
        ),
      );
    });

    testWidgets('no evidence card with only 2 entries', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: false),
            records: [
              _record(id: 'a', daysAgo: 1, contextIds: const ['work']),
              _record(id: 'b', contextIds: const ['work']),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('pressure_personal_evidence_card')),
        findsNothing,
      );
    });

    testWidgets('Pro users see the evidence card too', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 4200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: true),
            records: _richRecords(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('pressure_personal_evidence_card')),
        findsOneWidget,
      );
    });
  });

  group('No VoiceMemory consumer copy', () {
    testWidgets('card never shows VoiceMemory', (tester) async {
      final summary = engine.build(_richRecords());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PressurePersonalEvidenceSummaryCard(summary: summary),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    test('engine copy never contains VoiceMemory', () {
      final summary = engine.build(_richRecords());
      final copy = [
        PressurePersonalEvidenceSummary.headline,
        summary.reasonLine,
        summary.confidenceLabel,
        ...summary.evidenceTerms,
      ].whereType<String>().join(' ');
      expect(copy, isNot(contains('VoiceMemory')));
    });
  });
}