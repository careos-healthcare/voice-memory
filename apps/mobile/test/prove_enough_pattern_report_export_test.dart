import 'package:archiveme_mobile/features/prove_enough/monthly_ambition_pressure_review_model.dart';
import 'package:archiveme_mobile/features/prove_enough/next_evidence_mission_engine.dart';
import 'package:archiveme_mobile/features/prove_enough/next_evidence_mission_model.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_contradiction_model.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_evidence_trail_engine.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_evidence_trail_model.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_pattern_report_exporter.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_pattern_report_model.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_pattern_report_pdf_exporter.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_pattern_report_service.dart';
import 'package:archiveme_mobile/features/signal_review/signal_review_model.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/prove_enough/prove_enough_pattern_report_export_button.dart';
import 'package:archiveme_research/screens/monthly_ambition_pressure_review_screen.dart';
import 'package:archiveme_research/screens/prove_enough_evidence_trail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'signal_review_engine_test.dart' show entry, journey;

ProveEnoughEvidenceTrail _sampleTrail() {
  const engine = ProveEnoughEvidenceTrailEngine();
  final entries = <JournalEntry>[
    entry(
      'e0',
      'I kept working late because stopping made me feel behind and not enough.',
    ),
    entry(
      'e1',
      'I did more to prove I was productive even though I was tired and drained.',
    ),
    entry(
      'e2',
      'I pushed through more work because rest felt unsafe and I felt behind.',
    ),
    entry(
      'e3',
      'I compared myself to everyone else and kept going to catch up on unfinished work.',
    ),
    entry(
      'e4',
      'I tried to rest during quiet time but felt guilt about stopping and being lazy.',
    ),
    entry(
      'e5',
      'I wanted to finish because I enjoyed it and chose to stay with a clear reason.',
    ),
  ];

  return engine.build(
    entries: entries,
    journey: journey(supporting: 5, contradicting: const ['e5']),
    review: SignalReview(
      id: 'sr1',
      journeyId: 'j1',
      signalTitle: 'Trying to prove enough',
      reviewStatus: SignalReviewStatus.ready,
      evidenceCount: 5,
      whatRepeated: 'Pressure may be repeating.',
      whatChanged: 'The same pressure to keep going may be repeating.',
      evidenceLines: const [],
      possibleContradictions: '',
      whatToWatchNext: '',
      nextEvidencePrompt: '',
      createdAt: DateTime(2026, 6, 3),
      updatedAt: DateTime(2026, 6, 3),
      loopModeId: 'prove_enough',
    ),
    contradictions: [
      ProveEnoughContradictionRecord(
        id: 'c1',
        option: ProveEnoughContradictionOption.restedWithoutGuilt,
        savedAt: DateTime(2026, 6, 4),
        journeyId: 'j1',
        entryId: 'e5',
      ),
    ],
    latestMission: const NextEvidenceMissionModel(
      mission: NextEvidenceMissionEngine.stoppingFeelsBehindMission,
      kind: NextEvidenceMissionKind.stoppingFeelsBehind,
    ),
  );
}

Future<void> _pumpFrames(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

const _pressureA =
    'I kept working late because stopping made me feel behind and not enough.';
const _restGuilt =
    'I tried to rest during quiet time but felt guilt about stopping and being lazy.';

ProveEnoughPatternReport _sampleReport() {
  final trail = _sampleTrail();
  return ProveEnoughPatternReport(
    generatedAt: DateTime(2026, 6, 7),
    trail: trail,
    monthlyReview: const MonthlyAmbitionPressureReview(
      monthLabel: 'June',
      totalProvingMoments: 4,
      pressureMomentCount: 2,
      choiceMomentCount: 1,
      restGuiltCount: 1,
      contradictionCount: 1,
      topTriggers: ['Work deadlines (2)'],
      direction: AmbitionPressureDirection.mixed,
      directionEvidence: [
        'Pressure moments: 2 this month vs 1 last month.',
      ],
      whatChanged: 'Pressure moments increased compared with last month.',
      nextMonthMission: NextEvidenceMissionEngine.stoppingFeelsBehindMission,
      whatRepeated: _pressureA,
      whatSeemedToCostYou: _restGuilt,
      choiceVsPressureSummary: 'Pressure: 2 · Choice: 1',
      restGuiltSummary: _restGuilt,
      triggerMapSummary: 'Work deadlines (2)',
    ),
    rangeStart: DateTime(2026, 6),
    rangeEnd: DateTime(2026, 6, 5),
  );
}

void main() {
  const exporter = ProveEnoughPatternReportExporter();
  const banned = ['therapy', 'coach', 'diagnosis', 'VoiceMemory'];

  group('ProveEnoughPatternReportExporter', () {
    test('markdown contains required sections', () {
      final markdown = exporter.toMarkdown(_sampleReport());

      expect(markdown, contains('# ${ProveEnoughPatternReport.reportTitle}'));
      for (final section in [
        ProveEnoughPatternReport.summarySection,
        ProveEnoughPatternReport.evidenceTrailSection,
        ProveEnoughPatternReport.choiceVsPressureSection,
        ProveEnoughPatternReport.restGuiltSection,
        ProveEnoughPatternReport.triggerMapSection,
        ProveEnoughPatternReport.confirmedSection,
        ProveEnoughPatternReport.challengedSection,
        ProveEnoughPatternReport.directionSection,
        ProveEnoughPatternReport.nextMissionSection,
      ]) {
        expect(markdown, contains('## $section'), reason: section);
      }
    });

    test('markdown uses real evidence only', () {
      final report = _sampleReport();
      final markdown = exporter.toMarkdown(report).toLowerCase();

      expect(markdown, contains(_pressureA.toLowerCase().split(' ').first));
      expect(markdown, contains(_restGuilt.toLowerCase().split(' ').first));
      expect(markdown, isNot(contains('invented quote')));
      expect(markdown, isNot(contains('lorem ipsum')));
    });

    test('no banned language in markdown', () {
      final markdown = exporter.toMarkdown(_sampleReport()).toLowerCase();
      for (final word in banned) {
        expect(markdown, isNot(contains(word.toLowerCase())));
      }
    });

    test('empty trail avoids invented excerpts', () {
      final markdown = exporter.toMarkdown(
        ProveEnoughPatternReport(
          generatedAt: DateTime(2026, 6, 7),
          trail: const ProveEnoughEvidenceTrail(
            supportingMoments: [],
            contradictionMoments: [],
            restGuiltMoments: [],
            choiceMoments: [],
            triggerSummary: '',
            whatChanged: '',
          ),
        ),
      );

      expect(markdown, contains('_No saved excerpts yet._'));
      expect(markdown, isNot(contains('"')));
    });
  });

  group('ProveEnoughPatternReportPdfExporter', () {
    test('PDF path is safe when unsupported', () async {
      expect(ProveEnoughPatternReportPdfExporter.isSupported, isFalse);
      final path = await const ProveEnoughPatternReportPdfExporter()
          .exportToFile(_sampleReport());
      expect(path, isNull);
    });
  });

  group('ProveEnoughPatternReportService', () {
    test('Pro user markdown generation succeeds', () {
      final markdown = ProveEnoughPatternReportService.markdownFor(
        _sampleReport(),
      );
      expect(markdown, contains(ProveEnoughPatternReport.reportTitle));
      expect(markdown, contains('ArchiveMe'));
    });
  });

  group('ProveEnoughPatternReportExportButton', () {
    testWidgets('free user sees Pro gate', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProveEnoughPatternReportExportButton(
              isPro: false,
              initialReport: _sampleReport(),
            ),
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(find.text(ProveEnoughPatternReport.proGateTitle), findsOneWidget);
      expect(
        find.byKey(const Key('prove_enough_pattern_report_pro_hint')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('prove_enough_pattern_report_export_button')),
      );
      await _pumpFrames(tester);

      expect(
        find.byKey(const Key('prove_enough_pattern_report_pro_gate')),
        findsOneWidget,
      );
    });

    testWidgets('Pro user can generate export', (tester) async {
      ProveEnoughPatternReport? exported;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProveEnoughPatternReportExportButton(
              isPro: true,
              initialReport: _sampleReport(),
              onExport: (report) async {
                exported = report;
              },
            ),
          ),
        ),
      );
      await _pumpFrames(tester);

      await tester.tap(
        find.byKey(const Key('prove_enough_pattern_report_export_button')),
      );
      await _pumpFrames(tester);

      expect(exported, isNotNull);
      expect(exported!.hasExportableContent, isTrue);
    });

    testWidgets('See Pro CTA routes to paywall', (tester) async {
      var routed = false;

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => ProveEnoughPatternReportExportButton(
              isPro: false,
              initialReport: _sampleReport(),
              onSeePro: () => context.push('/subscription'),
            ),
          ),
          GoRoute(
            path: '/subscription',
            builder: (context, state) {
              routed = true;
              return const Scaffold(body: Text('Paywall screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await _pumpFrames(tester);

      await tester.tap(
        find.byKey(const Key('prove_enough_pattern_report_export_button')),
      );
      await _pumpFrames(tester);
      await tester.tap(
        find.byKey(const Key('prove_enough_pattern_report_see_pro_cta')),
      );
      await _pumpFrames(tester);

      expect(routed, isTrue);
      expect(find.text('Paywall screen'), findsOneWidget);
    });
  });

  group('screen integration', () {
    testWidgets('evidence trail screen shows export button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      await tester.pumpWidget(
        MaterialApp(
          home: ProveEnoughEvidenceTrailScreen(
            initialTrail: _sampleTrail(),
            initialEntitlements: const PremiumEntitlements(
              tier: BillingTier.pro,
              entitlementIds: ['pro'],
              billingConnected: true,
              source: 'test',
            ),
          ),
        ),
      );
      await _pumpFrames(tester);

      await tester.scrollUntilVisible(
        find.text(ProveEnoughPatternReportExportButton.buttonLabel),
        300,
      );
      expect(
        find.text(ProveEnoughPatternReportExportButton.buttonLabel),
        findsOneWidget,
      );
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('monthly review screen shows export button for Pro', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      await tester.pumpWidget(
        MaterialApp(
          home: MonthlyAmbitionPressureReviewScreen(
            initialReview: _sampleReport().monthlyReview,
            initialEntitlements: const PremiumEntitlements(
              tier: BillingTier.pro,
              entitlementIds: ['pro'],
              billingConnected: true,
              source: 'test',
            ),
          ),
        ),
      );
      await _pumpFrames(tester);

      await tester.scrollUntilVisible(
        find.text(ProveEnoughPatternReportExportButton.buttonLabel),
        300,
      );
      expect(
        find.text(ProveEnoughPatternReportExportButton.buttonLabel),
        findsOneWidget,
      );
    });
  });
}