import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_copy.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_layout.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/early_archive/positive_pattern_copy.dart';
import 'package:voicememory_mobile/features/early_archive/positive_pattern_engine.dart';
import 'package:voicememory_mobile/features/early_archive/positive_reinforcement_analytics.dart';
import 'package:voicememory_mobile/features/early_archive/positive_reinforcement_copy.dart';
import 'package:voicememory_mobile/features/early_archive/positive_reinforcement_engine.dart';
import 'package:voicememory_mobile/features/early_archive/positive_reinforcement_gates.dart';
import 'package:voicememory_mobile/features/voice_capture/record_cta_policy.dart';
import 'package:voicememory_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/security/privacy_copy_policy.dart';
import 'package:voicememory_mobile/widgets/record/positive_reinforcement_card.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: transcript,
  durationSeconds: 30,
  localAudioPath: '/tmp/$id.m4a',
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up in this moment.',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _threeWalkEntries() => [
  _entry(
    id: 'w1',
    transcript: 'I walked outside before starting and felt clearer.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _entry(
    id: 'w2',
    transcript: 'Work was heavy but I walked outside at lunch.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    id: 'w3',
    transcript: 'Another stuck day — walked outside when I needed air.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

List<JournalEntry> _threeRelatedRepeatEntries() => [
  _entry(
    id: 'e1',
    transcript:
        'I had no capacity but I said yes again to the extra meeting today.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _entry(
    id: 'e2',
    transcript:
        'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    id: 'e3',
    transcript:
        'I said yes again even though I had no capacity for one more ask.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

List<JournalEntry> _mixedRepeatAndWalkEntries() => [
  ..._threeRelatedRepeatEntries(),
  _entry(
    id: 'w4',
    transcript: 'I walked outside before replying and it helped.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
  _entry(
    id: 'w5',
    transcript: 'Same week I walked outside again before the hard email.',
    createdAt: DateTime(2026, 6, 14, 12),
  ),
];

void _expectNoDiagnosticLanguage(String copy) {
  final lower = copy.toLowerCase();
  expect(lower, isNot(contains('diagnosis')));
  expect(lower, isNot(contains('therapy')));
  expect(lower, isNot(contains('disorder')));
}

void main() {
  setUp(PositiveReinforcementAnalytics.resetForTest);

  group('PositiveReinforcementEngine', () {
    test('hidden without positive pattern', () {
      expect(
        PositiveReinforcementEngine.build(
          positivePattern: null,
          entries: _threeWalkEntries(),
        ),
        isNull,
      );
      expect(
        PositiveReinforcementEngine.build(
          positivePattern: PositivePatternEngine.build(
            entries: _threeRelatedRepeatEntries(),
          ),
          entries: _threeRelatedRepeatEntries(),
        ),
        isNull,
      );
    });

    test('visible with positive pattern', () {
      final pattern = PositivePatternEngine.build(
        entries: _mixedRepeatAndWalkEntries(),
      );
      final reinforcement = PositiveReinforcementEngine.build(
        positivePattern: pattern,
        entries: _mixedRepeatAndWalkEntries(),
      );
      expect(pattern, isNotNull);
      expect(reinforcement, isNotNull);
      expect(reinforcement!.title, PositiveReinforcementCopy.title);
      expect(reinforcement.body, PositiveReinforcementCopy.body);
    });

    test('uses grounded helpful action phrase', () {
      final pattern = PositivePatternEngine.build(
        entries: _mixedRepeatAndWalkEntries(),
      );
      final reinforcement = PositiveReinforcementEngine.build(
        positivePattern: pattern,
        entries: _mixedRepeatAndWalkEntries(),
      );
      expect(reinforcement, isNotNull);
      expect(
        reinforcement!.evidencePhrases.join(' ').toLowerCase(),
        contains('walked outside'),
      );
      expect(
        reinforcement.guidedRecordPrompt,
        PositiveReinforcementCopy.guidedRecordPrompt,
      );
    });

    test('no generic positivity without action evidence', () {
      final entries = [
        _entry(
          id: 'g1',
          transcript: 'Feeling grateful today and a good day overall.',
          createdAt: DateTime(2026, 6, 10, 12),
        ),
        _entry(
          id: 'g2',
          transcript: 'Another grateful day and feeling better.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _entry(
          id: 'g3',
          transcript: 'Positive morning and happy start.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];
      expect(
        PositiveReinforcementEngine.build(
          positivePattern: PositivePatternEngine.build(entries: entries),
          entries: entries,
        ),
        isNull,
      );
    });

    test('completion state when helpful action appears again', () {
      final pattern = PositivePatternEngine.build(entries: _threeWalkEntries());
      final reinforcement = PositiveReinforcementEngine.build(
        positivePattern: pattern,
        entries: _threeWalkEntries(),
      );
      expect(reinforcement, isNotNull);
      expect(reinforcement!.isCompletion, isTrue);
      expect(reinforcement.title, PositiveReinforcementCopy.completionTitle);
      expect(reinforcement.body, PositiveReinforcementCopy.completionBody);
    });

    test('completion via helpful action milestone', () {
      final pattern = PositivePatternEngine.build(
        entries: _mixedRepeatAndWalkEntries(),
      );
      final reinforcement = PositiveReinforcementEngine.build(
        positivePattern: pattern,
        entries: _mixedRepeatAndWalkEntries(),
        helpfulActionCapturedMilestone: true,
      );
      expect(reinforcement, isNotNull);
      expect(reinforcement!.isCompletion, isTrue);
    });
  });

  group('PositiveReinforcementGates', () {
    test('hidden while recording', () {
      expect(
        PositiveReinforcementGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: true,
          hasPositivePattern: true,
        ),
        isFalse,
      );
    });

    test('record CTA hides on completion and when capture primary visible', () {
      expect(
        PositiveReinforcementGates.showRecordAgainCta(
          policy: const RecordCtaPolicyResolution(
            state: RecordCtaPolicyState.returning,
            primaryLabel: ConsumerUiCopy.recordMomentCta,
            showMainBottomCta: true,
            action: RecordCtaAction.startRecording,
          ),
          hideCardRecordButtons: true,
          promoteMicCaptureActions: false,
          isCompletion: false,
        ),
        isFalse,
      );
      expect(
        PositiveReinforcementGates.showRecordAgainCta(
          policy: const RecordCtaPolicyResolution(
            state: RecordCtaPolicyState.returning,
            primaryLabel: ConsumerUiCopy.recordMomentCta,
            showMainBottomCta: true,
            action: RecordCtaAction.startRecording,
          ),
          hideCardRecordButtons: false,
          promoteMicCaptureActions: false,
          isCompletion: true,
        ),
        isFalse,
      );
    });
  });

  group('PositiveReinforcementCopy', () {
    test('safe language', () {
      final lines = [
        PositiveReinforcementCopy.title,
        PositiveReinforcementCopy.body,
        PositiveReinforcementCopy.recordAgainCta,
        PositiveReinforcementCopy.completionTitle,
        PositiveReinforcementCopy.completionBody,
      ];
      _expectNoDiagnosticLanguage(lines.join(' '));
      for (final line in lines) {
        for (final reason in PrivacyCopyPolicy.violationsInLiteral(line)) {
          fail('"$line": $reason');
        }
      }
    });
  });

  group('PositiveReinforcementCard', () {
    testWidgets('renders loop copy and evidence', (tester) async {
      final pattern = PositivePatternEngine.build(
        entries: _mixedRepeatAndWalkEntries(),
      );
      final reinforcement = PositiveReinforcementEngine.build(
        positivePattern: pattern,
        entries: _mixedRepeatAndWalkEntries(),
      );
      expect(reinforcement, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PositiveReinforcementCard(
              reinforcement: reinforcement!,
              showRecordAgainCta: true,
              onRecordAgain: () {},
            ),
          ),
        ),
      );

      expect(find.text(PositiveReinforcementCopy.title), findsOneWidget);
      expect(find.text(PositiveReinforcementCopy.body), findsOneWidget);
      expect(
        find.text(PositiveReinforcementCopy.recordAgainCta),
        findsOneWidget,
      );
      expect(find.textContaining('walked outside'), findsWidgets);
      expect(find.text(PositivePatternCopy.title), findsNothing);
    });

    testWidgets('CTA routes to record guided prompt', (tester) async {
      final pattern = PositivePatternEngine.build(
        entries: _mixedRepeatAndWalkEntries(),
      );
      final reinforcement = PositiveReinforcementEngine.build(
        positivePattern: pattern,
        entries: _mixedRepeatAndWalkEntries(),
      );
      expect(reinforcement, isNotNull);

      String? tappedPrompt;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PositiveReinforcementCard(
              reinforcement: reinforcement!,
              showRecordAgainCta: true,
              onRecordAgain: () {
                tappedPrompt = reinforcement.guidedRecordPrompt;
              },
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('positive_reinforcement_record_cta')),
      );
      await tester.pump();
      expect(tappedPrompt, PositiveReinforcementCopy.guidedRecordPrompt);
    });

    testWidgets('no transcript text in card', (tester) async {
      final entries = _mixedRepeatAndWalkEntries();
      final pattern = PositivePatternEngine.build(entries: entries);
      final reinforcement = PositiveReinforcementEngine.build(
        positivePattern: pattern,
        entries: entries,
      );
      expect(reinforcement, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PositiveReinforcementCard(
              reinforcement: reinforcement!,
              showRecordAgainCta: false,
            ),
          ),
        ),
      );

      expect(find.textContaining(entries.first.transcript), findsNothing);
    });
  });

  group('PositiveReinforcementAnalytics', () {
    test('metadata only without transcript text', () {
      Map<String, Object>? captured;
      PositiveReinforcementAnalytics.captureForTest = (event, props) {
        captured = props;
      };
      PositiveReinforcementAnalytics.recordTapped(
        surface: 'record',
        entryCount: 5,
        helpfulPatternRecorded: true,
      );
      expect(captured, isNotNull);
      expect(
        captured!.keys,
        containsAll([
          'surface',
          'entry_count',
          'helpful_pattern_seen',
          'helpful_pattern_recorded',
        ]),
      );
      expect(captured!.keys, isNot(contains('transcript')));
    });
  });

  group('Positive reinforcement dedup', () {
    test('no duplicate positive cards when reinforcement replaces pattern', () {
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: true,
        timelineVisible: false,
        changeProofVisible: false,
        proBridgeVisible: false,
        positiveReinforcementVisible: true,
        positivePatternVisible: true,
      );
      expect(layout.effectivePositivePatternVisible, isFalse);
      expect(layout.effectivePositiveReinforcementVisible, isTrue);

      final blocks = ArchiveProofSurfaceCopy.patternsStack(
        layout: layout,
        confirmedRepeat: EarlyFirstSignalEngine.build(
          entries: _threeRelatedRepeatEntries(),
        ),
      );
      expect(blocks, contains(PositiveReinforcementCopy.title));
      expect(blocks, isNot(contains(PositivePatternCopy.title)));
      expect(
        blocks.where((block) => block == PositiveReinforcementCopy.title),
        hasLength(1),
      );
    });

    test('folds into Archive Summary without duplicate reinforcement card', () {
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: false,
        timelineVisible: false,
        changeProofVisible: false,
        proBridgeVisible: false,
        positiveReinforcementVisible: true,
        archiveSummaryVisible: true,
      );
      expect(layout.effectivePositiveReinforcementVisible, isFalse);
      final blocks = ArchiveProofSurfaceCopy.patternsStack(layout: layout);
      expect(blocks, isNot(contains(PositiveReinforcementCopy.title)));
      expect(blocks, isNot(contains(PositivePatternCopy.title)));
    });
  });
}
