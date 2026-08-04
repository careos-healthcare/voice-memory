import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_quality.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_current_belief_engine.dart';
import 'package:voicememory_mobile/features/daily_question/adaptive_daily_question_engine.dart';
import 'package:voicememory_mobile/features/early_archive/archive_change_timeline_engine.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_evidence_quality_fallback_view.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';
const _realMoment =
    'I felt pressure to say yes again before checking my capacity today.';
const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';

JournalEntry _voiceEntry({
  required String id,
  String transcript = '',
  String observation = '',
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 10),
  transcript: transcript,
  durationSeconds: 24,
  localAudioPath: '/tmp/$id.m4a',
  reflection: Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: const [],
    exactLanguagePattern: '',
    concreteObservation: observation,
    repeatedSignal: '',
  ),
  syncStatus: SyncStatus.localOnly,
);

JournalEntry _textEntry(String id, String transcript) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 10 + id.hashCode % 5),
  transcript: transcript,
  durationSeconds: 24,
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

List<JournalEntry> _threeStrongRepeatEntries() => [
  _textEntry('e1', _strongRepeat),
  _textEntry(
    'e2',
    'I had no capacity but said yes again to one more work meeting.',
  ),
  _textEntry(
    'e3',
    'I said yes again to an extra meeting even though I had no capacity.',
  ),
];

void main() {
  group('ArchiveEvidenceQuality', () {
    test('placeholder voice draft is unusable', () {
      final verdict = ArchiveEvidenceQuality.assess(
        _voiceEntry(id: 'p', transcript: _placeholder),
      );
      expect(verdict.level, ArchiveEvidenceQualityLevel.unusable);
      expect(
        verdict.reason,
        anyOf(
          ArchiveEvidenceQualityReason.placeholderOrPending,
          ArchiveEvidenceQualityReason.degradedVoice,
        ),
      );
      expect(verdict.allowsInsights, isFalse);
    });

    test('pending transcript is unusable', () {
      final verdict = ArchiveEvidenceQuality.assess(
        _voiceEntry(
          id: 'p',
          transcript: _placeholder,
          observation: _realMoment,
        ),
      );
      expect(verdict.level, ArchiveEvidenceQualityLevel.unusable);
      expect(verdict.allowsInsights, isFalse);
    });

    test('generic test text is weak', () {
      final verdict = ArchiveEvidenceQuality.assess(
        _textEntry('t', 'hello checking mic test'),
      );
      expect(verdict.level, ArchiveEvidenceQualityLevel.weak);
      expect(
        verdict.reason,
        anyOf(
          ArchiveEvidenceQualityReason.genericTestText,
          ArchiveEvidenceQualityReason.lowSignal,
        ),
      );
      expect(verdict.allowsInsights, isFalse);
    });

    test('everything is working alone is weak', () {
      final verdict = ArchiveEvidenceQuality.assess(
        _textEntry('t', 'everything is working'),
      );
      expect(verdict.level, ArchiveEvidenceQualityLevel.weak);
      expect(verdict.allowsInsights, isFalse);
    });

    test('real moment is usable or strong', () {
      final verdict = ArchiveEvidenceQuality.assess(
        _textEntry('r', _realMoment),
      );
      expect(verdict.allowsInsights, isTrue);
      expect(
        verdict.level,
        anyOf(
          ArchiveEvidenceQualityLevel.usable,
          ArchiveEvidenceQualityLevel.strong,
        ),
      );
    });

    test('long concrete repeat moment is strong', () {
      final verdict = ArchiveEvidenceQuality.assess(
        _textEntry('s', _strongRepeat),
      );
      expect(verdict.level, ArchiveEvidenceQualityLevel.strong);
      expect(verdict.allowsProofSurfaces, isTrue);
    });
  });

  group('ArchiveEvidenceQualityGate', () {
    test('mixed entries use only real evidence', () {
      final entries = [
        _voiceEntry(
          id: 'p',
          transcript: _placeholder,
          observation: _realMoment,
        ),
        _textEntry('2', _realMoment),
        _textEntry('3', 'I said yes again when I had no capacity left today.'),
      ];
      final usable = ArchiveEvidenceQualityGate.usableEntries(entries);
      expect(usable.length, 2);
      expect(usable.every((e) => !e.transcript.startsWith('[draft]')), isTrue);
    });

    test('no early signal from weak-only evidence', () {
      final entries = [_textEntry('1', 'hello'), _textEntry('2', 'testing')];
      expect(ArchiveEvidenceQualityGate.allowsEarlySignals(entries), isFalse);
      expect(EarlyFirstSignalEngine.build(entries: entries), isNull);
    });

    test('no first proof from weak-only evidence', () {
      final entries = List.generate(
        3,
        (i) => _textEntry('$i', 'short vague note $i'),
      );
      expect(ArchiveEvidenceQualityGate.allowsFirstProof(entries), isFalse);
      expect(FirstProofMomentEngine.build(entries: entries), isNull);
    });

    test('no belief surface without strong evidence foundation', () {
      final entries = List.generate(
        3,
        (i) => _textEntry('$i', 'kind of tired maybe $i'),
      );
      expect(ArchiveEvidenceQualityGate.allowsBeliefSurfaces(entries), isFalse);
      expect(
        ArchiveCurrentBeliefEngine.build(
          entries: entries,
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNull,
      );
    });

    test('confirmed repeat phrases ignore placeholder entries', () {
      final entries = [
        ...List.generate(
          3,
          (i) => _voiceEntry(id: 'p$i', transcript: _placeholder),
        ),
      ];
      expect(
        ConfirmedRepeatEvidencePhraseEngine.extract(entries).phrases,
        isEmpty,
      );
    });

    test('proof engines allow three strong repeat entries', () {
      final entries = _threeStrongRepeatEntries();
      expect(ArchiveEvidenceQualityGate.allowsFirstProof(entries), isTrue);
      expect(FirstProofMomentEngine.build(entries: entries), isNotNull);
      expect(
        PrivateArchiveReportEngine.build(
          entries: entries,
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNotNull,
      );
      expect(
        ArchiveChangeTimelineEngine.build(
          entries: entries,
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNotNull,
      );
    });

    test('adaptive daily question skips placeholder-only archive', () {
      final entries = List.generate(
        3,
        (i) => _voiceEntry(id: 'p$i', transcript: _placeholder),
      );
      final question = AdaptiveDailyQuestionEngine.build(entries: entries);
      expect(question.usesPhrase, isNot(true));
    });

    test('shows weak evidence fallback state', () {
      final entries = [_textEntry('1', 'hello testing mic')];
      expect(
        ArchiveEvidenceQualityGate.showsWeakEvidenceFallback(entries),
        isTrue,
      );
      expect(
        ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries),
        isFalse,
      );
    });

    test('shows pending transcript fallback state', () {
      final entries = [_voiceEntry(id: 'p', transcript: _placeholder)];
      expect(
        ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries),
        isTrue,
      );
      expect(
        ArchiveEvidenceQualityGate.showsWeakEvidenceFallback(entries),
        isFalse,
      );
      expect(
        ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries),
        isFalse,
      );
    });

    test('simulator harness strings block pattern hypothesis', () {
      const testOne = 'This is a test to check function';
      const testTwo = 'This is a second test for pressure';
      final entries = [_textEntry('1', testOne), _textEntry('2', testTwo)];
      for (final text in [testOne, testTwo]) {
        expect(ArchiveEvidenceQuality.isGenericTestText(text), isTrue);
        expect(
          ArchiveEvidenceQuality.assess(_textEntry('x', text)).allowsInsights,
          isFalse,
        );
      }
      expect(
        ArchiveEvidenceQualityGate.allowsPatternHypothesis(entries),
        isFalse,
      );
      expect(
        ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries),
        isTrue,
      );
    });
  });

  group('UI fallback copy', () {
    testWidgets('weak evidence fallback card shows quality copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PatternsEvidenceQualityFallbackView(savedEntryId: 'e1'),
          ),
        ),
      );

      expect(find.text(ArchiveEvidenceQualityCopy.savedTitle), findsOneWidget);
      expect(
        find.text(ArchiveEvidenceQualityCopy.needsClearerWordsBody),
        findsOneWidget,
      );
    });

    testWidgets('generic test fallback shows forming copy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PatternsEvidenceQualityFallbackView(
              savedEntryId: 'e1',
              genericTestOnly: true,
            ),
          ),
        ),
      );

      expect(
        find.text(ArchiveEvidenceQualityCopy.patternsStillFormingTitle),
        findsOneWidget,
      );
      expect(
        find.text(ArchiveEvidenceQualityCopy.patternsNeedClearerMomentsBody),
        findsOneWidget,
      );
      expect(find.text(ArchiveEvidenceQualityCopy.savedTitle), findsNothing);
    });
  });

  test('ArchiveEvidenceGuard delegates to quality gate', () {
    expect(
      ArchiveEvidenceGuard.hasUsableReflectionText(
        _textEntry('r', _realMoment),
      ),
      isTrue,
    );
    expect(
      ArchiveEvidenceGuard.hasUsableReflectionText(
        _voiceEntry(id: 'p', transcript: _placeholder),
      ),
      isFalse,
    );
    expect(
      ArchiveEvidenceGuard.hasStrongReflectionText(
        _textEntry('s', _strongRepeat),
      ),
      isTrue,
    );
  });
}
