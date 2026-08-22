import 'dart:io';
import 'support/record_screen_library_source.dart';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/archive_timeline_spine/archive_timeline_spine_analytics.dart';
import 'package:archiveme_mobile/features/archive_timeline_spine/archive_timeline_spine_copy.dart';
import 'package:archiveme_mobile/features/archive_timeline_spine/archive_timeline_spine_engine.dart';
import 'package:archiveme_mobile/features/archive_timeline_spine/archive_timeline_spine_model.dart';
import 'package:archiveme_mobile/features/correction_memory/correction_memory_engine.dart';
import 'package:archiveme_mobile/features/correction_memory/correction_memory_store.dart';
import 'package:archiveme_mobile/features/current_relevance/current_relevance_model.dart';
import 'package:archiveme_mobile/features/current_relevance/current_relevance_store.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/widgets/patterns/archive_timeline_spine_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_storage_sandbox.dart';

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
    hasConfirmedRepeat: EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
      entries,
    ),
    source: 'test',
  );
}

ArchiveTimelineSpineResult _manualResult({
  required ArchiveTimelineSpineCurrentWeight weight,
  List<ArchiveTimelineSpineRowId> rowIds = const [
    ArchiveTimelineSpineRowId.firstSeen,
  ],
}) => ArchiveTimelineSpineResult(
  shouldShow: true,
  entryCount: 3,
  source: 'test',
  hasConfirmedRepeat: true,
  hasCorrection: rowIds.contains(ArchiveTimelineSpineRowId.correctedByYou),
  currentWeight: weight,
  rows: rowIds
      .map(
        (id) => ArchiveTimelineSpineRow(
          id: id,
          label: ArchiveTimelineSpineCopy.labelFor(id),
          detail: ArchiveTimelineSpineCopy.detailFor(id),
        ),
      )
      .toList(),
  title: ArchiveTimelineSpineCopy.title,
  subtitle: ArchiveTimelineSpineCopy.subtitle,
  explanation: ArchiveTimelineSpineCopy.explanation,
  currentWeightLabel: ArchiveTimelineSpineCopy.currentWeightLabelFor(weight),
  footer: ArchiveTimelineSpineCopy.footer,
  differentiationLine: ArchiveTimelineSpineCopy.differentiationLine,
  proBridgeCopy: ArchiveTimelineSpineCopy.proBridgeCopy,
  evidenceAnchors: const [],
  hasSafeAnchor: false,
  patternMatchQuality: PatternMatchQualityResult.hidden(
    source: 'test',
    entryCount: 3,
  ),
  proofConfidenceCalibration: ProofConfidenceCalibrationResult.hidden(
    source: 'test',
    entryCount: 3,
  ),
);

ArchiveTimelineSpineResult _resultFor(
  List<JournalEntry> entries, {
  bool beliefSurfaceVisible = true,
  DateTime? now,
}) {
  final built = ArchiveTimelineSpineEngine.build(
    entries: entries,
    beliefSurfaceVisible: beliefSurfaceVisible,
    source: 'test',
    now: now ?? _now,
  );
  expect(built, isNotNull);
  return built!;
}

bool _hasRow(ArchiveTimelineSpineResult result, ArchiveTimelineSpineRowId id) =>
    result.rows.any((row) => row.id == id);

void main() {
  late TestStorageSandbox sandbox;
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    ArchiveTimelineSpineAnalytics.resetForTest();
    ArchiveTimelineSpineAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    await CurrentRelevanceStore.resetForTest();
    await CorrectionMemoryStore.resetForTest();
    analyticsEvents.clear();
  });

  tearDown(() => sandbox.dispose());
  tearDown(() async {
    ArchiveTimelineSpineAnalytics.resetForTest();
    await CorrectionMemoryStore.resetForTest();
    await CurrentRelevanceStore.resetForTest();
  });

  group('ArchiveTimelineSpineEngine', () {
    test('hidden when not enough evidence', () {
      expect(
        ArchiveTimelineSpineEngine.build(
          entries: [_entry('1', _strongRepeat)],
          beliefSurfaceVisible: true,
          source: 'test',
        ),
        isNull,
      );
    });

    test('renders first seen row for eligible entries', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(_hasRow(result, ArchiveTimelineSpineRowId.firstSeen), isTrue);
    });

    test('renders returned row when confirmed repeat exists', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(_hasRow(result, ArchiveTimelineSpineRowId.returned), isTrue);
    });

    test('renders corrected row when correction exists', () async {
      final entries = _threeRelatedEntries();
      await _saveCorrection(entries, CurrentRelevanceAnswer.little);

      final result = _resultFor(entries);
      expect(_hasRow(result, ArchiveTimelineSpineRowId.correctedByYou), isTrue);
      expect(result.hasCorrection, isTrue);
    });

    test('renders weight changed row for softened signals', () async {
      final entries = _threeRelatedEntries();
      await _saveCorrection(entries, CurrentRelevanceAnswer.little);

      final result = _resultFor(entries);
      expect(_hasRow(result, ArchiveTimelineSpineRowId.weightChanged), isTrue);
    });

    test('renders needs fresh proof row for stale repeat evidence', () {
      final result = _resultFor(_staleRepeatEntries());
      expect(
        _hasRow(result, ArchiveTimelineSpineRowId.needsFreshProof),
        isTrue,
      );
    });

    test('current weight strong for recent confirmed repeat', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(result.currentWeight, ArchiveTimelineSpineCurrentWeight.strong);
    });

    test(
      'current weight light for belief surface without confirmed repeat',
      () {
        final entries = [
          _entry(
            '1',
            'Work felt heavy today and I stayed late again.',
            createdAt: DateTime(2026, 6, 8, 12),
          ),
          _entry(
            '2',
            'Still thinking about work pressure and saying yes too often.',
            createdAt: DateTime(2026, 6, 10, 12),
          ),
          _entry(
            '3',
            'Another long day at work with the same tired feeling.',
            createdAt: DateTime(2026, 6, 11, 12),
          ),
        ];
        final result = _resultFor(entries);
        expect(result.currentWeight, ArchiveTimelineSpineCurrentWeight.light);
      },
    );

    test('current weight corrected when user corrected', () async {
      final entries = _threeRelatedEntries();
      await _saveCorrection(entries, CurrentRelevanceAnswer.yes);

      final result = _resultFor(entries);
      expect(result.currentWeight, ArchiveTimelineSpineCurrentWeight.corrected);
    });

    test('current weight needs fresh proof for stale evidence', () {
      final result = _resultFor(_staleRepeatEntries());
      expect(
        result.currentWeightLabel,
        ArchiveTimelineSpineCopy.currentWeightNeedsFreshProof,
      );
    });

    test('hidden during first proof payoff', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(
        ArchiveTimelineSpineEngine.shouldShowOnPatterns(
          result: result,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: true,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden during What Changed', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(
        ArchiveTimelineSpineEngine.shouldShowOnRecordReady(
          result: result,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: true,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden during degraded transcript', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(
        ArchiveTimelineSpineEngine.shouldShowOnPatterns(
          result: result,
          isDegradedTranscriptState: true,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('suppresses duplicate education stack when visible', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(
        ArchiveTimelineSpineEngine.suppressLegacyEducationCards(
          result: result,
          visible: true,
        ),
        isTrue,
      );
      expect(
        ArchiveTimelineSpineEngine.suppressLegacyEducationCards(
          result: result,
          visible: false,
        ),
        isFalse,
      );
    });
  });

  group('ArchiveTimelineSpineCard', () {
    Future<void> pumpCard(
      WidgetTester tester,
      ArchiveTimelineSpineResult result,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveTimelineSpineCard.test(
                result: result,
                source: 'test',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders "Archive timeline"', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.text(ArchiveTimelineSpineCopy.title), findsOneWidget);
    });

    testWidgets('renders "Not a chat. A record of what changed over time."', (
      tester,
    ) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.text(ArchiveTimelineSpineCopy.subtitle), findsOneWidget);
    });

    testWidgets('renders first seen row', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(
        find.text(ArchiveTimelineSpineCopy.firstSeenLabel),
        findsOneWidget,
      );
    });

    testWidgets('renders returned row when confirmed repeat exists', (
      tester,
    ) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.text(ArchiveTimelineSpineCopy.returnedLabel), findsOneWidget);
    });

    testWidgets('renders corrected row when correction exists', (tester) async {
      await pumpCard(
        tester,
        _manualResult(
          weight: ArchiveTimelineSpineCurrentWeight.corrected,
          rowIds: const [
            ArchiveTimelineSpineRowId.firstSeen,
            ArchiveTimelineSpineRowId.returned,
            ArchiveTimelineSpineRowId.correctedByYou,
          ],
        ),
      );

      expect(
        find.text(ArchiveTimelineSpineCopy.correctedLabel),
        findsOneWidget,
      );
    });

    testWidgets('renders weight changed row for softened signals', (
      tester,
    ) async {
      await pumpCard(
        tester,
        _manualResult(
          weight: ArchiveTimelineSpineCurrentWeight.light,
          rowIds: const [
            ArchiveTimelineSpineRowId.firstSeen,
            ArchiveTimelineSpineRowId.returned,
            ArchiveTimelineSpineRowId.weightChanged,
          ],
        ),
      );

      expect(
        find.text(ArchiveTimelineSpineCopy.weightChangedLabel),
        findsOneWidget,
      );
    });

    testWidgets('renders needs fresh proof row for stale evidence', (
      tester,
    ) async {
      await pumpCard(tester, _resultFor(_staleRepeatEntries()));

      expect(
        find.text(ArchiveTimelineSpineCopy.needsFreshProofLabel),
        findsOneWidget,
      );
    });

    testWidgets('renders current weight strong', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(
        find.text(ArchiveTimelineSpineCopy.currentWeightStrong),
        findsOneWidget,
      );
    });

    testWidgets('renders current weight light', (tester) async {
      await pumpCard(
        tester,
        _manualResult(weight: ArchiveTimelineSpineCurrentWeight.light),
      );

      expect(
        find.text(ArchiveTimelineSpineCopy.currentWeightLight),
        findsOneWidget,
      );
    });

    testWidgets('renders current weight fading', (tester) async {
      await pumpCard(
        tester,
        _manualResult(weight: ArchiveTimelineSpineCurrentWeight.fading),
      );

      expect(
        find.text(ArchiveTimelineSpineCopy.currentWeightFading),
        findsOneWidget,
      );
    });

    testWidgets('renders current weight corrected', (tester) async {
      await pumpCard(
        tester,
        _manualResult(
          weight: ArchiveTimelineSpineCurrentWeight.corrected,
          rowIds: const [
            ArchiveTimelineSpineRowId.firstSeen,
            ArchiveTimelineSpineRowId.correctedByYou,
          ],
        ),
      );

      expect(
        find.text(ArchiveTimelineSpineCopy.currentWeightCorrected),
        findsOneWidget,
      );
    });

    testWidgets('renders current weight needs fresh proof', (tester) async {
      await pumpCard(tester, _resultFor(_staleRepeatEntries()));

      expect(
        find.text(ArchiveTimelineSpineCopy.currentWeightNeedsFreshProof),
        findsOneWidget,
      );
    });

    testWidgets('renders ChatGPT differentiation line', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(
        find.text(ArchiveTimelineSpineCopy.differentiationLine),
        findsOneWidget,
      );
    });

    testWidgets('renders "Your past is context, not a verdict."', (
      tester,
    ) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.text(ArchiveTimelineSpineCopy.footer), findsOneWidget);
    });

    testWidgets('no transcript/body/private text', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.textContaining(_strongRepeat), findsNothing);
      expect(find.textContaining('localAudioPath'), findsNothing);
      expect(find.textContaining('transcript'), findsNothing);
    });

    testWidgets('no Pro CTA inside card', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.textContaining('See Pro'), findsNothing);
      expect(find.textContaining('Subscribe'), findsNothing);
      expect(find.byKey(const Key('pro_evidence_value_cta')), findsNothing);
    });

    testWidgets('metadata-only analytics', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(analyticsEvents, hasLength(1));
      final record = analyticsEvents.single;
      expect(record.event, ArchiveTimelineSpineAnalytics.seenEvent);
      expect(
        record.props.keys,
        containsAll([
          'source',
          'entry_count',
          'has_confirmed_repeat',
          'has_correction',
          'current_weight_state',
          'row_count',
        ]),
      );
      for (final value in record.props.values) {
        final text = value.toString().toLowerCase();
        expect(text, isNot(contains('transcript')));
        expect(text, isNot(contains(_strongRepeat.toLowerCase())));
      }
    });
  });

  group('Archive timeline spine placement', () {
    test('patterns card sits below ArchiveBeliefSurfaceCard', () {
      final source = File(
        'lib/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      final beliefIndex = source.indexOf('ArchiveBeliefSurfaceCard(');
      final spineIndex = source.indexOf('ArchiveTimelineSpineCard(');
      expect(beliefIndex, greaterThan(0));
      expect(spineIndex, greaterThan(beliefIndex));
    });

    test('patterns suppresses legacy education cards when spine visible', () {
      final source = File(
        'lib/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      expect(source, contains('suppressLegacyEducationCardsForSpine'));
      expect(source, contains('!suppressLegacyEducationCardsForSpine'));
      expect(source, contains('showCurrentRelevanceOnPatterns'));
    });

    test('record card sits below ArchiveBeliefSurfaceCard', () {
      final source = readRecordScreenLibrarySource();
      final beliefIndex = source.indexOf('showArchiveCurrentBeliefOnRecord');
      final spineIndex = source.indexOf('showArchiveTimelineSpineOnRecord');
      expect(beliefIndex, greaterThan(0));
      expect(spineIndex, greaterThan(beliefIndex));
    });
  });

  group('Archive timeline spine copy guard', () {
    test('no therapy/diagnosis/treatment claims', () {
      final blob = ArchiveTimelineSpineCopy.allVisibleStrings()
          .join(' ')
          .toLowerCase();
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('treatment')));
      expect(blob, isNot(contains('better than chatgpt')));
    });

    test('copy passes advice guard', () {
      for (final line in ArchiveTimelineSpineCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });

    test('feature files avoid billing surfaces', () {
      const paths = [
        'lib/features/archive_timeline_spine/archive_timeline_spine_copy.dart',
        'lib/features/archive_timeline_spine/archive_timeline_spine_engine.dart',
        'lib/features/archive_timeline_spine/archive_timeline_spine_analytics.dart',
        'lib/widgets/patterns/archive_timeline_spine_card.dart',
      ];
      for (final path in paths) {
        final content = File(path).readAsStringSync().toLowerCase();
        expect(content, isNot(contains('revenuecat')));
        expect(content, isNot(contains('restorepurchase')));
        expect(content, isNot(contains('billing/')));
      }
    });
  });
}