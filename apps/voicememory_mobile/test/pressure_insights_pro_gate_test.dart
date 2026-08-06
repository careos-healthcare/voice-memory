import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/features/pressure_retention/archive_reflection_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_evidence_confidence.dart';
import 'package:archiveme_research/screens/pressure_insights_screen.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/ask_the_archive_card.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/pressure_confidence_label.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/pressure_pro_upgrade_card.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/pressure_report_share_button.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/pressure_weekly_recap_card.dart';

PressureCheckInRecord _record({
  required String id,
  required DateTime createdAt,
  String optionId = 'did_more_to_not_feel_behind',
  List<String> contextIds = const ['work'],
  String? fear,
  bool choseToStop = false,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: createdAt,
    optionId: optionId,
    contextIds: contextIds,
    fear: fear,
    choseToStop: choseToStop,
    transcript: 'I did more so I wouldn\'t feel behind.',
  );
}

Future<void> _pumpCard(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(390, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required bool pro,
  required List<PressureCheckInRecord> records,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: PressureInsightsScreen(
        entitlementReader: FakeArchiveEntitlementReader(pro: pro),
        records: records,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  final now = DateTime.now();

  List<PressureCheckInRecord> sampleRecords() => [
    _record(id: 'a', createdAt: now),
    _record(id: 'b', createdAt: now.subtract(const Duration(days: 1))),
    _record(id: 'c', createdAt: now.subtract(const Duration(days: 2))),
  ];

  group('Free user pressure insights', () {
    testWidgets('sees the preview with basic loop + limited recap', (
      tester,
    ) async {
      await _pumpScreen(tester, pro: false, records: sampleRecords());

      expect(
        find.byKey(const Key('pressure_loop_visibility_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('pressure_weekly_recap_card')),
        findsOneWidget,
      );
      // Limited recap preview copy is shown to free users.
      expect(
        find.text(PressureWeeklyRecapCard.previewMoreCopy),
        findsOneWidget,
      );
      // No Pro-only confidence label or share button leaks into the free view.
      expect(find.byKey(const Key('pressure_confidence_label')), findsNothing);
      expect(
        find.byKey(const Key('pressure_report_share_button')),
        findsNothing,
      );
    });

    testWidgets('CTA copy appears', (tester) async {
      await _pumpScreen(tester, pro: false, records: sampleRecords());
      expect(find.text(PressureProUpgradeCard.ctaLabel), findsWidgets);
    });

    testWidgets('sees Ask the Archive locked', (tester) async {
      await _pumpScreen(tester, pro: false, records: sampleRecords());

      // The four questions still render so the value is visible.
      for (final q in const ArchiveReflectionEngine().questions()) {
        expect(find.text(q.prompt), findsOneWidget);
      }
      expect(find.text(AskTheArchiveCard.lockedSubtitle), findsOneWidget);
    });
  });

  group('Ask the Archive lock behavior', () {
    testWidgets('locked questions trigger upgrade and never answer', (
      tester,
    ) async {
      var unlocks = 0;
      await _pumpCard(
        tester,
        AskTheArchiveCard(
          records: sampleRecords(),
          locked: true,
          onUnlock: () => unlocks++,
        ),
      );

      await tester.tap(find.text('Where does this repeat?'));
      await tester.pump();

      expect(unlocks, 1);
      expect(find.byKey(const Key('ask_the_archive_answer')), findsNothing);
    });
  });

  group('Pro user pressure insights', () {
    testWidgets('Ask the Archive is unlocked and answers questions', (
      tester,
    ) async {
      await _pumpScreen(tester, pro: true, records: sampleRecords());

      expect(find.text(AskTheArchiveCard.subtitle), findsOneWidget);

      // The pattern reveal card adds height; scroll the question into view.
      await tester.ensureVisible(find.text('Where does this repeat?'));
      await tester.pump();
      await tester.tap(find.text('Where does this repeat?'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('ask_the_archive_answer')), findsOneWidget);
    });

    testWidgets('sees the full weekly recap, no upgrade CTA', (tester) async {
      await _pumpScreen(tester, pro: true, records: sampleRecords());

      expect(find.text(PressureWeeklyRecapCard.previewMoreCopy), findsNothing);
      expect(find.text('Most common context'), findsOneWidget);
      expect(find.text(PressureProUpgradeCard.ctaLabel), findsNothing);
    });

    testWidgets('sees confidence label and shareable report', (tester) async {
      await _pumpScreen(tester, pro: true, records: sampleRecords());

      expect(
        find.byKey(const Key('pressure_confidence_label')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('pressure_report_share_button')),
        findsOneWidget,
      );
    });
  });

  group('Evidence confidence', () {
    const engine = PressureEvidenceConfidenceEngine();

    test('weak evidence needs more', () {
      expect(
        engine.fromRecords([_record(id: 'a', createdAt: now)]),
        PressureEvidenceConfidence.needsMoreEvidence,
      );
    });

    test('a few varied entries are an early signal', () {
      final records = [
        _record(id: 'a', createdAt: now, optionId: 'one'),
        _record(id: 'b', createdAt: now, optionId: 'two'),
      ];
      expect(
        engine.fromRecords(records),
        PressureEvidenceConfidence.earlySignal,
      );
    });

    test('strong repetition is a strong pattern', () {
      final records = List.generate(
        5,
        (i) => _record(id: 'r$i', createdAt: now, optionId: 'same'),
      );
      expect(
        engine.fromRecords(records),
        PressureEvidenceConfidence.strongPattern,
      );
    });

    testWidgets('label widget renders weak and strong copy', (tester) async {
      await _pumpCard(
        tester,
        const PressureConfidenceLabel(
          confidence: PressureEvidenceConfidence.needsMoreEvidence,
        ),
      );
      expect(find.text('Needs more evidence'), findsOneWidget);

      await _pumpCard(
        tester,
        const PressureConfidenceLabel(
          confidence: PressureEvidenceConfidence.strongPattern,
        ),
      );
      expect(find.text('Strong pattern'), findsOneWidget);
    });
  });

  group('No VoiceMemory consumer copy', () {
    testWidgets('free and Pro views never show VoiceMemory', (tester) async {
      await _pumpScreen(tester, pro: false, records: sampleRecords());
      expect(find.textContaining('VoiceMemory'), findsNothing);

      await _pumpScreen(tester, pro: true, records: sampleRecords());
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });
  });

  test('share button is unused-import guard', () {
    // Ensures the Pro share button type is wired into the gate test.
    expect(PressureReportShareButton.label, 'Share pressure report');
  });
}
