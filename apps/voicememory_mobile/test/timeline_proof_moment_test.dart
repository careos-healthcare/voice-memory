import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/archive_timeline_spine/archive_timeline_spine_engine.dart';
import 'package:voicememory_mobile/features/archive_timeline_spine/archive_timeline_spine_model.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_engine.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_store.dart';
import 'package:voicememory_mobile/features/current_relevance/current_relevance_model.dart';
import 'package:voicememory_mobile/features/current_relevance/current_relevance_store.dart';
import 'package:voicememory_mobile/features/timeline_proof_moment/timeline_proof_moment_analytics.dart';
import 'package:voicememory_mobile/features/timeline_proof_moment/timeline_proof_moment_copy.dart';
import 'package:voicememory_mobile/features/timeline_proof_moment/timeline_proof_moment_engine.dart';
import 'package:voicememory_mobile/features/timeline_proof_moment/timeline_proof_moment_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/patterns/timeline_proof_moment_card.dart';

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
    hasConfirmedRepeat: true,
    source: 'test',
  );
}

TimelineProofMomentResult _resultFor(
  List<JournalEntry> entries, {
  bool beliefSurfaceVisible = true,
}) {
  final built = TimelineProofMomentEngine.build(
    entries: entries,
    beliefSurfaceVisible: beliefSurfaceVisible,
    source: 'test',
    now: _now,
  );
  expect(built, isNotNull);
  return built!;
}

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    TimelineProofMomentAnalytics.resetForTest();
    TimelineProofMomentAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/timeline_proof_moment/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/timeline_proof_moment/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    await CurrentRelevanceStore.resetForTest();
    await CorrectionMemoryStore.resetForTest();
    analyticsEvents.clear();
  });

  tearDown(() async {
    TimelineProofMomentAnalytics.resetForTest();
    await CorrectionMemoryStore.resetForTest();
    await CurrentRelevanceStore.resetForTest();
  });

  group('TimelineProofMomentEngine', () {
    test('hidden below 3 entries', () {
      expect(
        TimelineProofMomentEngine.build(
          entries: [_entry('1', _strongRepeat)],
          beliefSurfaceVisible: true,
          source: 'test',
        ),
        isNull,
      );
    });

    test('hidden without meaningful spine rows', () {
      final spine = ArchiveTimelineSpineEngine.build(
        entries: _threeRelatedEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(spine, isNotNull);
      final trimmedSpine = ArchiveTimelineSpineResult(
        shouldShow: true,
        entryCount: spine!.entryCount,
        source: 'test',
        hasConfirmedRepeat: spine.hasConfirmedRepeat,
        hasCorrection: spine.hasCorrection,
        currentWeight: spine.currentWeight,
        rows: [spine.rows.first],
        title: spine.title,
        subtitle: spine.subtitle,
        explanation: spine.explanation,
        currentWeightLabel: spine.currentWeightLabel,
        footer: spine.footer,
        differentiationLine: spine.differentiationLine,
        proBridgeCopy: spine.proBridgeCopy,
      );
      expect(
        TimelineProofMomentEngine.buildFromSpine(
          spine: trimmedSpine,
          entries: _threeRelatedEntries(),
          source: 'test',
        ),
        isNull,
      );
    });

    test('renders returned row when confirmed repeat exists', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(
        result.rows.any((row) => row.label == TimelineProofMomentCopy.returnedRow),
        isTrue,
      );
    });

    test('renders corrected row only when correction exists', () async {
      final entries = _threeRelatedEntries();
      final without = _resultFor(entries);
      expect(
        without.rows.any(
          (row) => row.label.startsWith(TimelineProofMomentCopy.correctedRowPrefix),
        ),
        isFalse,
      );

      await _saveCorrection(entries, CurrentRelevanceAnswer.little);
      final withCorrection = _resultFor(entries);
      expect(
        withCorrection.rows.any(
          (row) => row.label.contains('partly current'),
        ),
        isTrue,
      );
    });

    test('hidden during degraded transcript', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(
        TimelineProofMomentEngine.shouldShowOnPatterns(
          result: result,
          timelineSpineVisible: true,
          isDegradedTranscriptState: true,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden during What Changed', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(
        TimelineProofMomentEngine.shouldShowOnRecordReady(
          result: result,
          isDegradedTranscriptState: false,
          whatChangedQuestionActive: true,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden during Pattern Review Inbox active item', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(
        TimelineProofMomentEngine.shouldShow(
          result: result,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: true,
          isRecording: false,
        ),
        isFalse,
      );
    });
  });

  group('TimelineProofMomentCard', () {
    Future<void> _pumpCard(
      WidgetTester tester,
      TimelineProofMomentResult result,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TimelineProofMomentCard.test(
                result: result,
                source: 'test',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders "This pattern has a timeline now."', (tester) async {
      await _pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.text(TimelineProofMomentCopy.title), findsOneWidget);
    });

    testWidgets('renders first seen row', (tester) async {
      await _pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.text(TimelineProofMomentCopy.firstSeenRow), findsOneWidget);
    });

    testWidgets('renders returned row when confirmed repeat exists', (
      tester,
    ) async {
      await _pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.text(TimelineProofMomentCopy.returnedRow), findsOneWidget);
    });

    testWidgets('renders current weight row', (tester) async {
      await _pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(
        find.text(TimelineProofMomentCopy.currentWeightStrong),
        findsOneWidget,
      );
    });

    testWidgets('renders footer "past as a verdict"', (tester) async {
      await _pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(
        find.textContaining('past as a verdict'),
        findsOneWidget,
      );
    });

    testWidgets('renders ChatGPT differentiation', (tester) async {
      await _pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(
        find.text(TimelineProofMomentCopy.differentiationLine),
        findsOneWidget,
      );
    });

    testWidgets('renders Pro line without CTA', (tester) async {
      await _pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.text(TimelineProofMomentCopy.proLine), findsOneWidget);
      expect(find.textContaining('See Pro'), findsNothing);
      expect(find.textContaining('Subscribe'), findsNothing);
    });

    testWidgets('no transcript/body/private text', (tester) async {
      await _pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.textContaining(_strongRepeat), findsNothing);
      expect(find.textContaining('localAudioPath'), findsNothing);
      expect(find.textContaining('transcript'), findsNothing);
    });

    testWidgets('metadata-only analytics', (tester) async {
      await _pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(analyticsEvents, hasLength(1));
      final record = analyticsEvents.single;
      expect(record.event, TimelineProofMomentAnalytics.seenEvent);
      expect(record.props.keys, containsAll([
        'source',
        'entry_count',
        'has_confirmed_repeat',
        'has_correction',
        'current_weight_state',
        'row_count',
      ]));
    });
  });

  group('Timeline proof moment placement', () {
    test('appears before ArchiveTimelineSpineCard on patterns', () {
      final source =
          File('lib/screens/archive_belief_screen.dart').readAsStringSync();
      final proofIndex = source.indexOf('TimelineProofMomentCard(');
      final spineIndex = source.indexOf('ArchiveTimelineSpineCard(');
      expect(proofIndex, greaterThan(0));
      expect(spineIndex, greaterThan(proofIndex));
    });
  });

  group('Timeline proof moment copy guard', () {
    test('no therapy/diagnosis/treatment claims', () {
      final blob =
          TimelineProofMomentCopy.allVisibleStrings().join(' ').toLowerCase();
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('treatment')));
      expect(blob, isNot(contains('better than chatgpt')));
    });

    test('copy passes advice guard', () {
      for (final line in TimelineProofMomentCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });

    test('feature files avoid billing surfaces', () {
      const paths = [
        'lib/features/timeline_proof_moment/timeline_proof_moment_copy.dart',
        'lib/features/timeline_proof_moment/timeline_proof_moment_engine.dart',
        'lib/widgets/patterns/timeline_proof_moment_card.dart',
      ];
      for (final path in paths) {
        final content = File(path).readAsStringSync().toLowerCase();
        expect(content, isNot(contains('revenuecat')));
        expect(content, isNot(contains('restorepurchase')));
      }
    });
  });
}
