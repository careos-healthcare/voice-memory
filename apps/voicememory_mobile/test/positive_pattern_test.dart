import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_copy.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_layout.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/early_archive/positive_pattern_analytics.dart';
import 'package:voicememory_mobile/features/early_archive/positive_pattern_copy.dart';
import 'package:voicememory_mobile/features/early_archive/positive_pattern_engine.dart';
import 'package:voicememory_mobile/features/early_archive/positive_pattern_gates.dart';
import 'package:voicememory_mobile/features/voice_capture/record_cta_policy.dart';
import 'package:voicememory_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/security/privacy_copy_policy.dart';
import 'package:voicememory_mobile/widgets/record/positive_pattern_card.dart';

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
  group('PositivePatternEngine', () {
    test('detects repeated helpful action from user words', () {
      final result = PositivePatternEngine.build(entries: _threeWalkEntries());
      expect(result, isNotNull);
      expect(result!.title, PositivePatternCopy.title);
      expect(result.body, contains('A helpful action appeared'));
      expect(result.body, contains('watching'));
      expect(result.evidencePhrases, isNotEmpty);
      expect(
        result.evidencePhrases.join(' ').toLowerCase(),
        contains('walked outside'),
      );
    });

    test('returns null without enough entries', () {
      expect(
        PositivePatternEngine.build(entries: _threeWalkEntries().sublist(0, 2)),
        isNull,
      );
    });

    test('returns null for confirmed repeat without helpful action cues', () {
      expect(
        PositivePatternEngine.build(entries: _threeRelatedRepeatEntries()),
        isNull,
      );
    });

    test('does not reuse confirmed repeat evidence phrases', () {
      final result = PositivePatternEngine.build(
        entries: _mixedRepeatAndWalkEntries(),
      );
      expect(result, isNotNull);
      final repeatPhrases = ConfirmedRepeatEvidencePhraseEngine.extract(
        _threeRelatedRepeatEntries(),
      ).phrases;
      for (final evidence in result!.evidencePhrases) {
        for (final repeat in repeatPhrases) {
          expect(evidence.toLowerCase(), isNot(contains(repeat.toLowerCase())));
        }
      }
    });

    test('ignores generic positivity without action cues', () {
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
      expect(PositivePatternEngine.build(entries: entries), isNull);
    });

    test('detects paused before replying pattern', () {
      final entries = [
        _entry(
          id: 'p1',
          transcript: 'I paused before replying to the email and saved myself.',
          createdAt: DateTime(2026, 6, 10, 12),
        ),
        _entry(
          id: 'p2',
          transcript: 'Same thread — paused before replying this time.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _entry(
          id: 'p3',
          transcript: 'Trying again to paused before replying when rushed.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];
      final result = PositivePatternEngine.build(entries: entries);
      expect(result, isNotNull);
      expect(
        result!.evidencePhrases.join(' ').toLowerCase(),
        contains('paused before'),
      );
    });
  });

  group('PositivePatternGates', () {
    test('hides before three entries and while recording', () {
      expect(
        PositivePatternGates.shouldShow(
          loaded: true,
          entryCount: 2,
          isReady: true,
          isRecording: false,
          hasPositivePattern: true,
        ),
        isFalse,
      );
      expect(
        PositivePatternGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: true,
          hasPositivePattern: true,
        ),
        isFalse,
      );
      expect(
        PositivePatternGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: false,
          hasPositivePattern: true,
        ),
        isTrue,
      );
    });

    test('record again CTA hides when capture primary is visible', () {
      expect(
        PositivePatternGates.showRecordAgainCta(
          policy: const RecordCtaPolicyResolution(
            state: RecordCtaPolicyState.returning,
            primaryLabel: ConsumerUiCopy.recordMomentCta,
            showMainBottomCta: true,
            action: RecordCtaAction.startRecording,
          ),
          hideCardRecordButtons: true,
          promoteMicCaptureActions: false,
        ),
        isFalse,
      );
    });
  });

  group('PositivePatternCopy', () {
    test('avoids therapy and generic positivity language', () {
      final lines = [
        PositivePatternCopy.title,
        PositivePatternCopy.body,
        PositivePatternCopy.recordAgainCta,
        PositivePatternCopy.guidedRecordPrompt,
      ];
      final copy = lines.join(' ');
      _expectNoDiagnosticLanguage(copy);
      for (final line in lines) {
        for (final reason in PrivacyCopyPolicy.violationsInLiteral(line)) {
          fail('"$line": $reason');
        }
      }
      expect(copy.toLowerCase(), isNot(contains('you always')));
      expect(copy.toLowerCase(), isNot(contains('this proves')));
    });
  });

  group('PositivePatternCard', () {
    testWidgets('renders title, body, evidence, and subtle CTA', (
      tester,
    ) async {
      final result = PositivePatternEngine.build(entries: _threeWalkEntries());
      expect(result, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PositivePatternCard(
              result: result!,
              showRecordAgainCta: true,
              onRecordAgain: () {},
            ),
          ),
        ),
      );

      expect(find.text(PositivePatternCopy.title), findsOneWidget);
      expect(find.text(result.body), findsOneWidget);
      expect(find.text(PositivePatternCopy.recordAgainCta), findsOneWidget);
      expect(find.textContaining('walked outside'), findsWidgets);
    });
  });

  group('PositivePatternAnalytics', () {
    test('omits transcript text', () {
      Map<String, Object>? captured;
      PositivePatternAnalytics.captureForTest = (event, props) {
        captured = props;
      };
      PositivePatternAnalytics.recordAgainTapped(
        surface: 'record',
        entryCount: 3,
      );
      expect(captured, isNotNull);
      expect(captured!.keys, containsAll(['surface', 'entry_count']));
      expect(captured!.keys, isNot(contains('transcript')));
    });
  });

  group('PositivePattern proof dedup', () {
    test('reinforcement replaces standalone positive pattern title', () {
      final confirmed = EarlyFirstSignalEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: true,
        timelineVisible: false,
        changeProofVisible: false,
        proBridgeVisible: false,
        positiveReinforcementVisible: true,
        positivePatternVisible: false,
      );
      final blocks = ArchiveProofSurfaceCopy.patternsStack(
        layout: layout,
        confirmedRepeat: confirmed,
      );
      expect(blocks, contains(EarlyFirstSignalCopy.threeEntrySeenThreeTimes));
      expect(blocks, isNot(contains(PositivePatternCopy.title)));
    });
  });
}
