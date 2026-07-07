import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/current_relevance/current_relevance_analytics.dart';
import 'package:voicememory_mobile/features/current_relevance/current_relevance_copy.dart';
import 'package:voicememory_mobile/features/current_relevance/current_relevance_engine.dart';
import 'package:voicememory_mobile/features/current_relevance/current_relevance_model.dart';
import 'package:voicememory_mobile/features/current_relevance/current_relevance_store.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:voicememory_mobile/features/pro_evidence_value/pro_evidence_value_engine.dart';
import 'package:voicememory_mobile/features/pro_evidence_value/pro_evidence_value_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/widgets/patterns/current_relevance_card.dart';
import 'dart:io';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';
const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';

JournalEntry _entry(
  String id,
  String transcript, {
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
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
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _entry(
        '2',
        'Same thing — said yes when I had no capacity for one more thing.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _entry(
        '3',
        'I said yes again even though I had no capacity for one more ask.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

CurrentRelevanceState _stateForEntries(List<JournalEntry> entries) {
  final built = CurrentRelevanceEngine.build(
    entries: entries,
    beliefSurfaceVisible: true,
  );
  expect(built, isNotNull);
  return built!;
}

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    CurrentRelevanceAnalytics.resetForTest();
    CurrentRelevanceAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/current_relevance/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/current_relevance/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    await CurrentRelevanceStore.resetForTest();
    analyticsEvents.clear();
  });

  tearDown(() async {
    CurrentRelevanceAnalytics.resetForTest();
    await CurrentRelevanceStore.resetForTest();
  });

  group('CurrentRelevanceCopy', () {
    test('defines question, options, responses, and differentiation line', () {
      expect(CurrentRelevanceCopy.title, 'Does this still affect today?');
      expect(
        CurrentRelevanceCopy.body,
        contains('appeared before'),
      );
      expect(
        CurrentRelevanceCopy.differentiationLine,
        contains('ChatGPT can respond to one conversation'),
      );
      expect(
        CurrentRelevanceCopy.responseFor(CurrentRelevanceAnswer.yes),
        contains('looks current'),
      );
      expect(
        CurrentRelevanceCopy.responseFor(CurrentRelevanceAnswer.little),
        contains('soft signal'),
      );
      expect(
        CurrentRelevanceCopy.responseFor(CurrentRelevanceAnswer.notReally),
        contains('not treat this as urgent'),
      );
      expect(
        CurrentRelevanceCopy.responseFor(CurrentRelevanceAnswer.notSure),
        contains('wait for stronger evidence'),
      );
    });
  });

  group('CurrentRelevanceEngine visibility', () {
    test('hidden at zero entries', () {
      expect(
        CurrentRelevanceEngine.build(
          entries: const [],
          beliefSurfaceVisible: true,
        ),
        isNull,
      );
    });

    test('hidden before confirmed repeat on record-ready path', () {
      final entries = [
        _entry('1', _strongRepeat, createdAt: DateTime(2026, 6, 12, 12)),
      ];
      final state = CurrentRelevanceEngine.build(
        entries: entries,
        beliefSurfaceVisible: false,
      );
      expect(state, isNull);
      expect(
        CurrentRelevanceEngine.shouldShowOnRecordReady(
          state: state,
          isZeroEntryState: false,
          isFirstRecordingState: true,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('shows with confirmed repeat and entryCount >= 3', () {
      final entries = _threeRelatedEntries();
      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
        isTrue,
      );
      final state = CurrentRelevanceEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
      );
      expect(state, isNotNull);
      expect(state!.entryCount, 3);
      expect(
        CurrentRelevanceEngine.shouldShowOnRecordReady(
          state: state,
          isZeroEntryState: false,
          isFirstRecordingState: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isTrue,
      );
    });

    test('hidden during first proof payoff', () {
      final entries = _threeRelatedEntries();
      final state = _stateForEntries(entries);
      expect(
        FirstProofPayoffEngine.build(entries: entries),
        isNotNull,
      );
      expect(
        CurrentRelevanceEngine.shouldShow(
          state: state,
          isZeroEntryState: false,
          isFirstRecordingState: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: true,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden during What Changed question', () {
      final state = _stateForEntries(_threeRelatedEntries());
      expect(
        CurrentRelevanceEngine.shouldShow(
          state: state,
          isZeroEntryState: false,
          isFirstRecordingState: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: true,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('active question blocks Pro evidence bridge', () {
      final entries = _threeRelatedEntries();
      final state = _stateForEntries(entries);
      expect(
        ProEvidenceValueEngine.shouldShowCard(
          ProEvidenceValueContext(
            surface: ProEvidenceValueSurface.recordReady,
            entryCount: entries.length,
            isPro: false,
            dismissed: false,
            firstProofPayoffSeen: true,
            hasConfirmedRepeatEvidence: true,
            privateReportPreviewVisible: false,
            weeklyReviewPreviewVisible: false,
            isZeroEntryState: false,
            isFirstRecordingState: false,
            isDegradedTranscriptState: false,
            isPostSaveDegradedState: false,
            firstProofTruthQuestionActive: false,
            whatChangedQuestionActive: false,
            currentRelevanceQuestionActive: true,
            patternReviewInboxHasActiveItems: false,
            exportReportsLive: true,
          ),
        ),
        isFalse,
      );
      expect(
        CurrentRelevanceEngine.isQuestionActive(
          state: state,
          visible: true,
        ),
        isTrue,
      );
    });
  });

  group('CurrentRelevanceCard', () {
    Future<void> _pumpCard(
      WidgetTester tester,
      CurrentRelevanceState state,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrentRelevanceCard.test(
              state: state,
              source: 'test',
            ),
          ),
        ),
      );
      await tester.pump();
    }

    CurrentRelevanceState _answeredState(CurrentRelevanceAnswer answer) {
      final entries = _threeRelatedEntries();
      final base = _stateForEntries(entries);
      return CurrentRelevanceState(
        proofKey: base.proofKey,
        entryCount: base.entryCount,
        hasConfirmedRepeat: base.hasConfirmedRepeat,
        answer: answer,
      );
    }

    testWidgets('copy renders question and options', (tester) async {
      await _pumpCard(tester, _stateForEntries(_threeRelatedEntries()));

      expect(find.byKey(const Key('current_relevance_card')), findsOneWidget);
      expect(find.text(CurrentRelevanceCopy.title), findsOneWidget);
      expect(find.text(CurrentRelevanceCopy.body), findsOneWidget);
      expect(find.text(CurrentRelevanceCopy.optionYes), findsOneWidget);
      expect(find.text(CurrentRelevanceCopy.optionLittle), findsOneWidget);
      expect(find.text(CurrentRelevanceCopy.optionNotReally), findsOneWidget);
      expect(find.text(CurrentRelevanceCopy.optionNotSure), findsOneWidget);
    });

    testWidgets('answer yes shows current response', (tester) async {
      await _pumpCard(tester, _answeredState(CurrentRelevanceAnswer.yes));

      expect(
        find.byKey(const Key('current_relevance_response_card')),
        findsOneWidget,
      );
      expect(
        find.text(CurrentRelevanceCopy.responseFor(CurrentRelevanceAnswer.yes)),
        findsOneWidget,
      );
      expect(
        find.text(CurrentRelevanceCopy.differentiationLine),
        findsOneWidget,
      );
    });

    testWidgets('answer a little shows soft signal response', (tester) async {
      await _pumpCard(tester, _answeredState(CurrentRelevanceAnswer.little));

      expect(
        find.text(
          CurrentRelevanceCopy.responseFor(CurrentRelevanceAnswer.little),
        ),
        findsOneWidget,
      );
    });

    testWidgets('answer not really shows not urgent response', (tester) async {
      await _pumpCard(tester, _answeredState(CurrentRelevanceAnswer.notReally));

      expect(
        find.text(
          CurrentRelevanceCopy.responseFor(CurrentRelevanceAnswer.notReally),
        ),
        findsOneWidget,
      );
    });

    testWidgets('answer not sure shows watch lightly response', (tester) async {
      await _pumpCard(tester, _answeredState(CurrentRelevanceAnswer.notSure));

      expect(
        find.text(
          CurrentRelevanceCopy.responseFor(CurrentRelevanceAnswer.notSure),
        ),
        findsOneWidget,
      );
    });

    testWidgets('differentiation line appears after answer', (tester) async {
      await _pumpCard(tester, _answeredState(CurrentRelevanceAnswer.yes));

      expect(
        find.byKey(const Key('current_relevance_differentiation_line')),
        findsOneWidget,
      );
    });

    test('selecting yes saves answer and tracks analytics', () async {
      final entries = _threeRelatedEntries();
      final state = _stateForEntries(entries);
      await CurrentRelevanceStore.instance().saveSelection(
        proofKey: state.proofKey,
        answer: CurrentRelevanceAnswer.yes,
        entryCountAtCapture: state.entryCount,
      );
      CurrentRelevanceAnalytics.answered(
        source: 'test',
        entryCount: state.entryCount,
        answer: CurrentRelevanceAnswer.yes,
        hasConfirmedRepeat: state.hasConfirmedRepeat,
      );

      expect(
        CurrentRelevanceStore.answerFor(state.proofKey),
        CurrentRelevanceAnswer.yes,
      );
      expect(
        analyticsEvents.any((event) => event.event == 'current_relevance_answered'),
        isTrue,
      );
    });
  });

  group('CurrentRelevanceAnalytics', () {
    test('metadata contains no private content', () async {
      final entries = _threeRelatedEntries();
      final state = _stateForEntries(entries);

      CurrentRelevanceAnalytics.seen(
        source: 'test',
        entryCount: state.entryCount,
        hasConfirmedRepeat: state.hasConfirmedRepeat,
      );
      CurrentRelevanceAnalytics.answered(
        source: 'test',
        entryCount: state.entryCount,
        answer: CurrentRelevanceAnswer.yes,
        hasConfirmedRepeat: state.hasConfirmedRepeat,
      );

      expect(analyticsEvents, hasLength(2));
      for (final record in analyticsEvents) {
        expect(record.event, anyOf('current_relevance_seen', 'current_relevance_answered'));
        expect(record.props.keys, contains('source'));
        expect(record.props.keys, contains('entry_count'));
        expect(record.props.keys, contains('has_confirmed_repeat'));
        for (final value in record.props.values) {
          final text = value.toString().toLowerCase();
          expect(text, isNot(contains('transcript')));
          expect(text, isNot(contains(_strongRepeat.toLowerCase())));
          expect(text, isNot(contains('capacity')));
        }
      }
      expect(analyticsEvents.last.props['answer_type'], 'yes');
    });
  });

  group('Current relevance placement', () {
    test('patterns screen renders relevance card before post-proof Pro bridge', () {
      final source =
          File('lib/screens/archive_belief_screen.dart').readAsStringSync();
      final relevanceIndex = source.indexOf('CurrentRelevanceCard(');
      final proBridgeIndex = source.indexOf(
        "analyticsSource: 'patterns_post_proof_pro_evidence_value'",
      );
      expect(relevanceIndex, greaterThan(0));
      expect(proBridgeIndex, greaterThan(relevanceIndex));
    });

    test('record screen renders relevance card before Pro evidence bridge', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      final relevanceIndex = source.indexOf('showCurrentRelevanceOnRecordReady');
      final proBridgeIndex = source.indexOf('showProEvidenceValueOnRecordReady');
      expect(relevanceIndex, greaterThan(0));
      expect(proBridgeIndex, greaterThan(relevanceIndex));
    });
  });

  group('Current relevance copy guard', () {
    test('no therapy or fake proof claims', () {
      final blob = CurrentRelevanceCopy.all.join(' ').toLowerCase();
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('guaranteed')));
      expect(blob, contains('chatgpt'));
    });
  });
}
