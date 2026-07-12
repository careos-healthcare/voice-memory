import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_today_summary/beta_today_summary_analytics.dart';
import 'package:voicememory_mobile/features/beta_today_summary/beta_today_summary_copy.dart';
import 'package:voicememory_mobile/features/beta_today_summary/beta_today_summary_engine.dart';
import 'package:voicememory_mobile/features/beta_today_summary/beta_today_summary_model.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_engine.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_store.dart';
import 'package:voicememory_mobile/features/current_relevance/current_relevance_model.dart';
import 'package:voicememory_mobile/features/current_relevance/current_relevance_store.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/beta/beta_today_summary_card.dart';

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

List<JournalEntry> _threeRelatedEntries({DateTime? anchor}) {
  final base = anchor ?? _now;
  return [
    _entry(
      '1',
      _strongRepeat,
      createdAt: base.subtract(const Duration(days: 2)),
    ),
    _entry(
      '2',
      'Same thing — said yes when I had no capacity for one more thing.',
      createdAt: base.subtract(const Duration(days: 1)),
    ),
    _entry(
      '3',
      'I said yes again even though I had no capacity for one more ask.',
      createdAt: base,
    ),
  ];
}

List<JournalEntry> _staleRepeatEntries() => [
      _entry('1', _strongRepeat, createdAt: DateTime(2026, 5, 1, 12)),
      _entry(
        '2',
        'Same thing — said yes when I had no capacity for one more thing.',
        createdAt: DateTime(2026, 5, 3, 12),
      ),
      _entry(
        '3',
        'I said yes again even though I had no capacity for one more ask.',
        createdAt: DateTime(2026, 5, 5, 12),
      ),
    ];

Future<void> _saveCorrection(
  List<JournalEntry> entries,
  CurrentRelevanceAnswer answer,
) async {
  final proofKey = CurrentRelevanceStore.proofKeyFor(entries);
  await CurrentRelevanceStore.instance().saveSelection(
    proofKey: proofKey,
    answer: answer,
    entryCountAtCapture: entries.length,
  );
  await CorrectionMemoryEngine.saveFromAnswer(
    proofKey: proofKey,
    answer: answer,
    entryCountAtCapture: entries.length,
    hasConfirmedRepeat:
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
    source: 'test',
  );
}

BetaTodaySummaryResult _buildSummary(
  List<JournalEntry> entries, {
  bool beliefSurfaceVisible = false,
  DateTime? now,
}) =>
    BetaTodaySummaryEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      source: 'test',
      now: now,
    );

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    ArchiveBetaMissionGate.resetForTest();
    BetaTodaySummaryAnalytics.resetForTest();
    BetaTodaySummaryAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/beta_today_summary/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/beta_today_summary/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    await CurrentRelevanceStore.resetForTest();
    await CorrectionMemoryStore.resetForTest();
  });

  tearDown(() {
    ArchiveBetaMissionGate.resetForTest();
    BetaTodaySummaryAnalytics.resetForTest();
  });

  group('BetaTodaySummaryEngine', () {
    test('uses fallback body with little evidence', () {
      final result = _buildSummary(const []);
      expect(result.usesFallbackBody, isTrue);
      expect(result.body, BetaTodaySummaryCopy.fallbackBody);
      expect(result.summaryRows, contains(BetaTodaySummaryCopy.noStrongPatternRow));
    });

    test('uses primary body with enough evidence', () {
      final result = _buildSummary(_threeRelatedEntries(), now: _now);
      expect(result.usesFallbackBody, isFalse);
      expect(result.body, BetaTodaySummaryCopy.primaryBody);
    });

    test('includes active pattern row when signal exists', () {
      final result = _buildSummary(_threeRelatedEntries(), now: _now);
      expect(result.summaryRows, contains(BetaTodaySummaryCopy.activePatternRow));
      expect(result.hasActivePattern, isTrue);
    });

    test('includes fading row when fading signal exists', () {
      final result = _buildSummary(_staleRepeatEntries(), now: _now);
      expect(result.summaryRows, contains(BetaTodaySummaryCopy.fadingRow));
      expect(result.hasFadingSignal, isTrue);
    });

    test('includes correction row when correction exists', () async {
      final entries = _threeRelatedEntries();
      await _saveCorrection(entries, CurrentRelevanceAnswer.little);
      final result = _buildSummary(entries, now: _now);
      expect(result.summaryRows, contains(BetaTodaySummaryCopy.correctionRow));
      expect(result.hasCorrection, isTrue);
    });

    test('includes needs fresh proof row when stale state exists', () {
      final result = _buildSummary(_staleRepeatEntries(), now: _now);
      expect(
        result.summaryRows,
        contains(BetaTodaySummaryCopy.needsFreshProofRow),
      );
    });

    test('hidden when beta flag false', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      final result = _buildSummary(_threeRelatedEntries(), now: _now);
      expect(
        BetaTodaySummaryEngine.shouldShow(
          result: result,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('visible when beta flag true', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildSummary(_threeRelatedEntries(), now: _now);
      expect(
        BetaTodaySummaryEngine.shouldShow(
          result: result,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isTrue,
      );
    });

    test('hidden while recording', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildSummary(_threeRelatedEntries(), now: _now);
      expect(
        BetaTodaySummaryEngine.shouldShow(
          result: result,
          isReady: true,
          isRecording: true,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden post-save', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildSummary(_threeRelatedEntries(), now: _now);
      expect(
        BetaTodaySummaryEngine.shouldShow(
          result: result,
          isReady: true,
          isRecording: false,
          isPostSave: true,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden degraded', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildSummary(_threeRelatedEntries(), now: _now);
      expect(
        BetaTodaySummaryEngine.shouldShow(
          result: result,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: true,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden during FirstProofPayoff', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildSummary(_threeRelatedEntries(), now: _now);
      expect(
        BetaTodaySummaryEngine.shouldShow(
          result: result,
          isReady: true,
          isRecording: false,
          isPostSave: false,
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
      final result = _buildSummary(_threeRelatedEntries(), now: _now);
      expect(
        BetaTodaySummaryEngine.shouldShow(
          result: result,
          isReady: true,
          isRecording: false,
          isPostSave: false,
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
      final result = _buildSummary(_threeRelatedEntries(), now: _now);
      expect(
        BetaTodaySummaryEngine.shouldShow(
          result: result,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: true,
        ),
        isFalse,
      );
    });
  });

  group('BetaTodaySummaryCard', () {
    Future<void> pumpCard(
      WidgetTester tester,
      BetaTodaySummaryResult result,
    ) async {
      ArchiveBetaMissionGate.enabledOverride = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BetaTodaySummaryCard.test(result: result),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders Today in your archive', (tester) async {
      await pumpCard(tester, _buildSummary(_threeRelatedEntries(), now: _now));
      expect(find.text(BetaTodaySummaryCopy.title), findsOneWidget);
    });

    testWidgets('renders You do not need to record today', (tester) async {
      await pumpCard(tester, _buildSummary(_threeRelatedEntries(), now: _now));
      expect(
        find.textContaining('You do not need to record today'),
        findsOneWidget,
      );
    });

    testWidgets('renders fallback body with little evidence', (tester) async {
      await pumpCard(tester, _buildSummary(const []));
      expect(find.text(BetaTodaySummaryCopy.fallbackBody), findsOneWidget);
    });

    testWidgets('renders Record if something stands out.', (tester) async {
      await pumpCard(tester, _buildSummary(_threeRelatedEntries(), now: _now));
      expect(find.text(BetaTodaySummaryCopy.closingLine), findsOneWidget);
    });

    testWidgets('metadata-only analytics', (tester) async {
      await pumpCard(tester, _buildSummary(_threeRelatedEntries(), now: _now));
      expect(analyticsEvents, isNotEmpty);
      final seen = analyticsEvents.firstWhere(
        (event) => event.event == BetaTodaySummaryAnalytics.seenEvent,
      );
      expect(seen.props.keys, containsAll([
        'source',
        'entry_count',
        'has_confirmed_repeat',
        'has_correction',
        'has_active_pattern',
        'has_fading_signal',
      ]));
      expect(seen.props.keys, isNot(contains('transcript')));
      expect(seen.props.keys, isNot(contains('body')));
      expect(seen.props.keys, isNot(contains('entry_id')));
    });
  });

  group('Beta today summary copy guard', () {
    test('no streak pressure copy', () {
      final blob =
          BetaTodaySummaryCopy.allVisibleStrings().join(' ').toLowerCase();
      expect(blob, isNot(contains('streak')));
      expect(blob, isNot(contains('day in a row')));
    });

    test('no daily requirement copy', () {
      final blob =
          BetaTodaySummaryCopy.allVisibleStrings().join(' ').toLowerCase();
      expect(blob, isNot(contains('must record every day')));
      expect(blob, contains('do not need to record today'));
      expect(blob, contains('does not need to be daily'));
    });

    test('no therapy/medical copy', () {
      for (final line in BetaTodaySummaryCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(line),
          isTrue,
          reason: 'failed on: $line',
        );
      }
    });

    test('feature files avoid billing surfaces', () {
      for (final path in [
        'lib/features/beta_today_summary/beta_today_summary_copy.dart',
        'lib/features/beta_today_summary/beta_today_summary_engine.dart',
        'lib/widgets/beta/beta_today_summary_card.dart',
      ]) {
        final source = File(path).readAsStringSync().toLowerCase();
        expect(source, isNot(contains('revenuecat')));
        expect(source, isNot(contains('subscription')));
      }
    });
  });

  group('Beta today summary placement', () {
    test('card sits below low-friction return and above capture freedom line', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      final lowFrictionIndex = source.indexOf('if (showLowFrictionReturnCard) ...[');
      final summaryIndex = source.indexOf('if (showBetaTodaySummaryCard) ...[');
      final freedomIndex = source.indexOf('if (showCaptureFreedomLine) ...[');
      expect(lowFrictionIndex, greaterThan(0));
      expect(summaryIndex, greaterThan(lowFrictionIndex));
      expect(freedomIndex, greaterThan(summaryIndex));
    });
  });
}
