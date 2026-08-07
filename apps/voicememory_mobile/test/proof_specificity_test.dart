import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/proof_specificity/proof_specificity_analytics.dart';
import 'package:voicememory_mobile/features/proof_specificity/proof_specificity_copy.dart';
import 'package:voicememory_mobile/features/proof_specificity/proof_specificity_engine.dart';
import 'package:voicememory_mobile/features/proof_specificity/proof_specificity_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/widgets/patterns/proof_specificity_card.dart';
import 'package:voicememory_mobile/widgets/record/capture_freedom_line.dart';

const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';
final _now = DateTime(2026, 6, 12, 12);

JournalEntry _entry(String id, String transcript, {DateTime? createdAt}) =>
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

ProofSpecificityResult _resultFor(
  List<JournalEntry> entries, {
  bool beliefSurfaceVisible = true,
  List<String> beliefEvidencePhrases = const [],
  String source = 'test',
}) => ProofSpecificityEngine.build(
  entries: entries,
  beliefSurfaceVisible: beliefSurfaceVisible,
  source: source,
  beliefEvidencePhrases: beliefEvidencePhrases,
);

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() {
    ProofSpecificityAnalytics.resetForTest();
    ProofSpecificityAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
  });

  tearDown(ProofSpecificityAnalytics.resetForTest);

  group('ProofSpecificityEngine', () {
    test('hidden below 3 entries for specificity card', () {
      final result = _resultFor([_entry('1', _strongRepeat)]);
      expect(result.shouldShow, isFalse);
      expect(
        ProofSpecificityEngine.shouldShowOnRecordReady(
          result: result,
          isZeroEntryState: false,
          isFirstRecordingState: false,
          isDegradedTranscriptState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('shows when confirmed repeat exists', () {
      final entries = _threeRelatedEntries();
      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
        isTrue,
      );
      final result = _resultFor(entries);
      expect(result.shouldShow, isTrue);
      expect(result.hasConfirmedRepeat, isTrue);
      expect(
        ProofSpecificityEngine.shouldShowOnRecordReady(
          result: result,
          isZeroEntryState: false,
          isFirstRecordingState: false,
          isDegradedTranscriptState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isTrue,
      );
    });

    test('shows safe fallback when no safe anchors exist', () {
      final result = ProofSpecificityResult(
        shouldShow: true,
        entryCount: 3,
        source: 'test',
        hasConfirmedRepeat: true,
        hasBeliefSurface: false,
        evidenceAnchorCount: 0,
        title: ProofSpecificityCopy.title,
        body: ProofSpecificityCopy.body,
        evidenceAnchors: const [],
        usesFallbackEvidenceLine: true,
        boundaryLine: ProofSpecificityCopy.boundaryLine,
        correctionLine: ProofSpecificityCopy.correctionLine,
        differentiationLine: ProofSpecificityCopy.differentiationLine,
      );
      expect(result.usesFallbackEvidenceLine, isTrue);
      expect(result.evidenceAnchors, isEmpty);
      expect(
        ProofSpecificityEngine.shouldShowOnRecordReady(
          result: result,
          isZeroEntryState: false,
          isFirstRecordingState: false,
          isDegradedTranscriptState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isTrue,
      );
    });

    test('blocked during degraded transcript/post-save', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(
        ProofSpecificityEngine.shouldShowOnRecordReady(
          result: result,
          isZeroEntryState: false,
          isFirstRecordingState: false,
          isDegradedTranscriptState: true,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
      expect(
        ProofSpecificityEngine.shouldShowOnFirstProofPayoff(
          result: result,
          isPostSaveDegradedState: true,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('blocked during What Changed active', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(
        ProofSpecificityEngine.shouldShowOnFirstProofPayoff(
          result: result,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: true,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });
  });

  group('ProofSpecificityCard', () {
    Future<void> pumpCard(
      WidgetTester tester,
      ProofSpecificityResult result,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProofSpecificityCard.test(result: result)),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders title "Why ArchiveMe noticed this"', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.byKey(const Key('proof_specificity_card')), findsOneWidget);
      expect(find.text(ProofSpecificityCopy.title), findsOneWidget);
    });

    testWidgets('renders "What repeated"', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.text(ProofSpecificityCopy.evidenceHeading), findsOneWidget);
    });

    testWidgets('renders boundary line', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(
        find.byKey(const Key('proof_specificity_boundary_line')),
        findsOneWidget,
      );
      expect(find.text(ProofSpecificityCopy.boundaryLine), findsOneWidget);
    });

    testWidgets('renders correction line', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(
        find.byKey(const Key('proof_specificity_correction_line')),
        findsOneWidget,
      );
      expect(find.text(ProofSpecificityCopy.correctionLine), findsOneWidget);
    });

    testWidgets('renders ChatGPT differentiation', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(
        find.byKey(const Key('proof_specificity_differentiation_line')),
        findsOneWidget,
      );
      expect(
        find.text(ProofSpecificityCopy.differentiationLine),
        findsOneWidget,
      );
    });

    testWidgets('does not include Pro CTA', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.textContaining('See Pro'), findsNothing);
      expect(find.textContaining('Subscribe'), findsNothing);
      expect(find.byKey(const Key('pro_evidence_value_cta')), findsNothing);
    });

    testWidgets('does not expose transcript/body/private text', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.textContaining(_strongRepeat), findsNothing);
      expect(find.textContaining('localAudioPath'), findsNothing);
      expect(find.textContaining('transcript'), findsNothing);
    });

    testWidgets('shows fallback evidence line when no anchors', (tester) async {
      final result = ProofSpecificityResult(
        shouldShow: true,
        entryCount: 3,
        source: 'test',
        hasConfirmedRepeat: true,
        hasBeliefSurface: false,
        evidenceAnchorCount: 0,
        title: ProofSpecificityCopy.title,
        body: ProofSpecificityCopy.body,
        evidenceAnchors: const [],
        usesFallbackEvidenceLine: true,
        boundaryLine: ProofSpecificityCopy.boundaryLine,
        correctionLine: ProofSpecificityCopy.correctionLine,
        differentiationLine: ProofSpecificityCopy.differentiationLine,
      );
      await pumpCard(tester, result);

      expect(
        find.byKey(const Key('proof_specificity_fallback_evidence')),
        findsOneWidget,
      );
      expect(
        find.text(ProofSpecificityCopy.fallbackEvidenceLine),
        findsOneWidget,
      );
    });

    testWidgets('analytics metadata only', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(analyticsEvents, hasLength(1));
      final record = analyticsEvents.single;
      expect(record.event, 'proof_specificity_seen');
      expect(
        record.props.keys,
        containsAll([
          'source',
          'entry_count',
          'has_confirmed_repeat',
          'has_belief_surface',
          'evidence_anchor_count',
        ]),
      );
      for (final value in record.props.values) {
        final text = value.toString().toLowerCase();
        expect(text, isNot(contains('transcript')));
        expect(text, isNot(contains(_strongRepeat.toLowerCase())));
        expect(text, isNot(contains('capacity')));
      }
    });
  });

  group('CaptureFreedomLine', () {
    Future<void> pumpLine(
      WidgetTester tester, {
      required int entryCount,
      bool compact = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CaptureFreedomLine.test(
              source: 'test',
              entryCount: entryCount,
              compact: compact,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('appears for zero-entry user', (tester) async {
      await pumpLine(tester, entryCount: 0);

      expect(find.byKey(const Key('capture_freedom_line')), findsOneWidget);
    });

    testWidgets('appears for early ready user', (tester) async {
      await pumpLine(tester, entryCount: 3, compact: true);

      expect(find.byKey(const Key('capture_freedom_line')), findsOneWidget);
      expect(
        find.byKey(const Key('capture_freedom_line_compact')),
        findsOneWidget,
      );
    });

    testWidgets('says user can record anything', (tester) async {
      await pumpLine(tester, entryCount: 0);

      expect(
        find.text(ProofSpecificityCopy.captureFreedomLine),
        findsOneWidget,
      );
      expect(find.textContaining('Record anything'), findsOneWidget);
    });

    testWidgets('does not mention therapy/diagnosis/treatment', (tester) async {
      await pumpLine(tester, entryCount: 0);
      await pumpLine(tester, entryCount: 2, compact: true);

      final blob = [
        ProofSpecificityCopy.captureFreedomLine,
        ProofSpecificityCopy.captureFreedomLineCompact,
      ].join(' ').toLowerCase();
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('treatment')));
    });

    testWidgets('capture freedom analytics metadata only', (tester) async {
      await pumpLine(tester, entryCount: 0);

      expect(analyticsEvents, hasLength(1));
      final record = analyticsEvents.single;
      expect(record.event, 'capture_freedom_line_seen');
      expect(
        record.props.keys,
        containsAll([
          'source',
          'entry_count',
          'has_confirmed_repeat',
          'has_belief_surface',
          'evidence_anchor_count',
        ]),
      );
    });
  });

  group('Proof specificity placement', () {
    test('patterns screen renders card before post-proof Pro bridge', () {
      final source = File(
        'lib/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      final cardIndex = source.indexOf('ProofSpecificityCard(');
      final proBridgeIndex = source.indexOf(
        "analyticsSource: 'patterns_post_proof_pro_evidence_value'",
      );
      expect(cardIndex, greaterThan(0));
      expect(proBridgeIndex, greaterThan(cardIndex));
    });

    test('record screen renders card before Pro evidence bridge', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      final cardIndex = source.indexOf('showProofSpecificityOnRecordReady');
      final proBridgeIndex = source.indexOf(
        'showProEvidenceValueOnRecordReady',
      );
      expect(cardIndex, greaterThan(0));
      expect(proBridgeIndex, greaterThan(cardIndex));
    });

    test('record post-save renders card before Pro evidence bridge', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      final cardIndex = source.indexOf(
        'showProofSpecificityOnFirstProofPayoff',
      );
      final proBridgeIndex = source.indexOf('showProEvidenceValuePostSave');
      expect(cardIndex, greaterThan(0));
      expect(proBridgeIndex, greaterThan(cardIndex));
    });

    test('patterns card sits after evidence weighting card', () {
      final source = File(
        'lib/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      final weightingIndex = source.indexOf('EvidenceWeightingCard(');
      final specificityIndex = source.indexOf('ProofSpecificityCard(');
      expect(weightingIndex, greaterThan(0));
      expect(specificityIndex, greaterThan(weightingIndex));
    });

    test('capture freedom line sits near RecordCaptureModesCard', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      final modesIndex = source.indexOf('RecordCaptureModesCard(');
      final freedomIndex = source.indexOf(
        'if (showCaptureFreedomLine && !firstUseSimplifiedRecord)',
      );
      expect(modesIndex, greaterThan(0));
      expect(freedomIndex, greaterThan(modesIndex));
    });
  });

  group('ProofSpecificity copy guard', () {
    test('no therapy or monetisation claims', () {
      final blob = ProofSpecificityCopy.all.join(' ').toLowerCase();
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('treatment')));
      expect(blob, isNot(contains('subscribe')));
      expect(blob, contains('chatgpt'));
    });
  });

  group('Capture freedom engine', () {
    test('shows for zero-entry ready user', () {
      expect(
        ProofSpecificityEngine.shouldShowCaptureFreedomLine(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          entryCount: 0,
        ),
        isTrue,
      );
    });

    test('hidden when recording or post-save', () {
      expect(
        ProofSpecificityEngine.shouldShowCaptureFreedomLine(
          isReady: true,
          isRecording: true,
          isPostSave: false,
          entryCount: 0,
        ),
        isFalse,
      );
      expect(
        ProofSpecificityEngine.shouldShowCaptureFreedomLine(
          isReady: true,
          isRecording: false,
          isPostSave: true,
          entryCount: 2,
        ),
        isFalse,
      );
    });
  });
}
