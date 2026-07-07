import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_tester_report/beta_tester_report_analytics.dart';
import 'package:voicememory_mobile/features/beta_tester_report/beta_tester_report_copy.dart';
import 'package:voicememory_mobile/features/beta_tester_report/beta_tester_report_engine.dart';
import 'package:voicememory_mobile/features/beta_tester_report/beta_tester_report_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/widgets/beta/beta_tester_report_card.dart';

const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';
final _now = DateTime(2026, 6, 12, 12);

JournalEntry _entry(
  String id,
  String transcript, {
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? _now,
      transcript: transcript,
      durationSeconds: 24,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up again today.',
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.localOnly,
    );

List<JournalEntry> _threeRelatedEntries() => [
      _entry(
        '1',
        _strongRepeat,
        createdAt: _now.subtract(const Duration(days: 2)),
      ),
      _entry(
        '2',
        'Same thing — said yes when I had no capacity for one more thing.',
        createdAt: _now.subtract(const Duration(days: 1)),
      ),
      _entry(
        '3',
        'I said yes again even though I had no capacity for one more ask.',
        createdAt: _now,
      ),
    ];

BetaTesterReportResult _buildReport(List<JournalEntry> entries) =>
    BetaTesterReportEngine.build(
      entries: entries,
      beliefSurfaceVisible: false,
      source: 'test',
      now: _now,
    );

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() {
    ArchiveBetaMissionGate.resetForTest();
    BetaTesterReportAnalytics.resetForTest();
    BetaTesterReportAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
  });

  tearDown(() {
    BetaTesterReportAnalytics.resetForTest();
  });

  group('BetaTesterReportEngine', () {
    test('hidden below 3 entries', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildReport([_entry('1', _strongRepeat)]);
      expect(result.shouldShow, isFalse);
      expect(
        BetaTesterReportEngine.shouldShowOnPatterns(
          result: result,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('visible with beta flag true', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildReport(_threeRelatedEntries());
      expect(
        BetaTesterReportEngine.shouldShowOnPatterns(
          result: result,
          patternReviewInboxHasActiveItems: false,
        ),
        isTrue,
      );
    });

    test('hidden with beta flag false', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      final result = _buildReport(_threeRelatedEntries());
      expect(
        BetaTesterReportEngine.shouldShowOnPatterns(
          result: result,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden degraded', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildReport(_threeRelatedEntries());
      expect(
        BetaTesterReportEngine.shouldShow(
          result: result,
          isReady: true,
          isRecording: false,
          isDegradedTranscriptState: true,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden while recording', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildReport(_threeRelatedEntries());
      expect(
        BetaTesterReportEngine.shouldShowOnRecord(
          result: result,
          isRecording: true,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          lowFrictionReturnVisible: false,
          betaTodaySummaryVisible: false,
          whatToNoticeNextVisible: false,
          openCapturePromptChipsVisible: false,
          timelineProofMomentVisible: true,
          archiveTimelineSpineVisible: true,
        ),
        isFalse,
      );
    });

    test('hidden during FirstProofPayoff', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildReport(_threeRelatedEntries());
      expect(
        BetaTesterReportEngine.shouldShowOnPatterns(
          result: result,
          patternReviewInboxHasActiveItems: false,
        ),
        isTrue,
      );
      expect(
        BetaTesterReportEngine.shouldShow(
          result: result,
          isReady: true,
          isRecording: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: true,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden during What Changed', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildReport(_threeRelatedEntries());
      expect(
        BetaTesterReportEngine.shouldShow(
          result: result,
          isReady: true,
          isRecording: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: true,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden during Pattern Review Inbox active item', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildReport(_threeRelatedEntries());
      expect(
        BetaTesterReportEngine.shouldShowOnPatterns(
          result: result,
          patternReviewInboxHasActiveItems: true,
        ),
        isFalse,
      );
    });

    test('Record placement respects SurfacePriorityAudit', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildReport(_threeRelatedEntries());
      expect(
        BetaTesterReportEngine.shouldShowOnRecord(
          result: result,
          isRecording: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          lowFrictionReturnVisible: true,
          betaTodaySummaryVisible: true,
          whatToNoticeNextVisible: false,
          openCapturePromptChipsVisible: false,
          timelineProofMomentVisible: true,
          archiveTimelineSpineVisible: true,
        ),
        isFalse,
      );
      expect(
        BetaTesterReportEngine.shouldShowOnRecord(
          result: result,
          isRecording: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          lowFrictionReturnVisible: false,
          betaTodaySummaryVisible: false,
          whatToNoticeNextVisible: false,
          openCapturePromptChipsVisible: false,
          timelineProofMomentVisible: true,
          archiveTimelineSpineVisible: true,
        ),
        isTrue,
      );
    });

    test('builds five sections', () {
      final result = _buildReport(_threeRelatedEntries());
      expect(result.sectionCount, 5);
      expect(
        result.sections.map((section) => section.heading),
        BetaTesterReportCopy.sectionOrder
            .map(BetaTesterReportCopy.headingFor)
            .toList(),
      );
    });
  });

  group('BetaTesterReportCard', () {
    Future<void> pumpCard(WidgetTester tester) async {
      ArchiveBetaMissionGate.enabledOverride = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BetaTesterReportCard.test(
                result: _buildReport(_threeRelatedEntries()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders Your first ArchiveMe report', (tester) async {
      await pumpCard(tester);
      expect(find.text(BetaTesterReportCopy.title), findsOneWidget);
    });

    testWidgets('renders Built from moments you saved.', (tester) async {
      await pumpCard(tester);
      expect(find.text(BetaTesterReportCopy.subtitle), findsOneWidget);
    });

    testWidgets('renders all five section headers', (tester) async {
      await pumpCard(tester);
      for (final section in BetaTesterReportCopy.sectionOrder) {
        expect(find.text(BetaTesterReportCopy.headingFor(section)), findsOneWidget);
      }
    });

    testWidgets('renders fallback lines', (tester) async {
      await pumpCard(tester);
      for (final section in BetaTesterReportCopy.sectionOrder) {
        expect(find.text(BetaTesterReportCopy.bodyFor(section)), findsOneWidget);
      }
    });

    testWidgets('renders No single moment proves the whole story.', (
      tester,
    ) async {
      await pumpCard(tester);
      expect(find.text(BetaTesterReportCopy.footer), findsOneWidget);
    });

    testWidgets('metadata-only analytics', (tester) async {
      await pumpCard(tester);
      expect(analyticsEvents, isNotEmpty);
      final seen = analyticsEvents.firstWhere(
        (event) => event.event == BetaTesterReportAnalytics.seenEvent,
      );
      expect(seen.props.keys, containsAll([
        'source',
        'entry_count',
        'has_confirmed_repeat',
        'has_correction',
        'has_fading_signal',
        'has_softening_signal',
        'section_count',
      ]));
      expect(seen.props.keys, isNot(contains('transcript')));
      expect(seen.props.keys, isNot(contains('body')));
      expect(seen.props.keys, isNot(contains('entry_id')));
    });
  });

  group('Beta tester report copy guard', () {
    test('no therapy/diagnosis/treatment claims', () {
      for (final line in BetaTesterReportCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(line),
          isTrue,
          reason: 'failed on: $line',
        );
      }
    });

    test('no subscription CTA', () {
      for (final path in [
        'lib/features/beta_tester_report/beta_tester_report_copy.dart',
        'lib/widgets/beta/beta_tester_report_card.dart',
      ]) {
        final source = File(path).readAsStringSync().toLowerCase();
        expect(source, isNot(contains('subscribe')));
        expect(source, isNot(contains('revenuecat')));
      }
    });

    test('no transcript/body/private text in analytics', () {
      final source = File(
        'lib/features/beta_tester_report/beta_tester_report_analytics.dart',
      ).readAsStringSync().toLowerCase();
      expect(source, isNot(contains('transcript')));
      expect(source, isNot(contains('entry_id')));
    });
  });

  group('Beta tester report placement', () {
    test('appears on Patterns below ArchiveTimelineSpineCard', () {
      final source =
          File('lib/screens/archive_belief_screen.dart').readAsStringSync();
      final spineIndex = source.indexOf('ArchiveTimelineSpineCard(');
      final reportIndex = source.indexOf('if (showBetaTesterReportOnPatterns)');
      expect(spineIndex, greaterThan(0));
      expect(reportIndex, greaterThan(spineIndex));
    });

    test('Record placement references SurfacePriorityAudit', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      expect(source, contains('SurfacePriorityEngine.auditRecordReady'));
      expect(source, contains('showBetaTesterReportOnRecord'));
      final engineSource = File(
        'lib/features/surface_priority/surface_priority_engine.dart',
      ).readAsStringSync();
      expect(engineSource, contains('SurfacePriorityCardKey.betaTesterReport'));
    });
  });
}
