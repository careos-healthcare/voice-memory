import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_quality.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:voicememory_mobile/features/first_session/first_session_pattern_engine.dart';
import 'package:voicememory_mobile/features/retention/pattern_hypothesis_engine.dart';
import 'package:voicememory_mobile/features/retention/second_session_signal_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

JournalEntry _textEntry(String id, String transcript) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 10 + id.hashCode % 5),
      transcript: transcript,
      durationSeconds: 24,
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.localOnly,
    );

void main() {
  const testOne = 'This is a test to check function';
  const testTwo = 'This is a second test for pressure';

  group('generic harness entries', () {
    test('user simulator strings classify as generic test', () {
      for (final text in [testOne, testTwo]) {
        expect(ArchiveEvidenceQuality.isGenericTestText(text), isTrue);
        final verdict = ArchiveEvidenceQuality.assess(_textEntry('x', text));
        expect(verdict.allowsInsights, isFalse);
        expect(verdict.reason, ArchiveEvidenceQualityReason.genericTestText);
      }
    });

    test('two generic harness entries show forming fallback only', () {
      final entries = [
        _textEntry('1', testOne),
        _textEntry('2', testTwo),
      ];
      expect(ArchiveEvidenceQualityGate.usableCount(entries), 0);
      expect(ArchiveEvidenceQualityGate.showsWeakEvidenceFallback(entries), isTrue);
      expect(
        ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries),
        isTrue,
      );
      expect(ArchiveEvidenceQualityGate.allowsPatternHypothesis(entries), isFalse);
      expect(ArchiveEvidenceQualityGate.allowsEarlyComparisons(entries), isFalse);
    });

    test('pattern engines return insufficient for generic harness', () async {
      final entries = [
        _textEntry('1', testOne),
        _textEntry('2', testTwo),
      ];
      const patternEngine = FirstSessionPatternEngine();
      for (final entry in entries) {
        final pattern = patternEngine.build(entry);
        expect(pattern.title, isEmpty);
        expect(pattern.chips, isEmpty);
        expect(pattern.categoryId, 'blocked');
      }

      final hypothesis = await const PatternHypothesisEngine().build(entries);
      expect(hypothesis.hasEnoughData, isFalse);
      expect(hypothesis.patternMightBe, isEmpty);

      final comparison = const SecondSessionSignalEngine().build(entries);
      expect(comparison.hasEnoughData, isFalse);
      expect(
        const SecondSessionSignalEngine().hasGroundedRepeatMatch(entries),
        isFalse,
      );
    });

    test('fallback pattern title never surfaces from generic text', () {
      final pattern = const FirstSessionPatternEngine().build(
        _textEntry('1', testTwo),
      );
      expect(pattern.title, isNot('Something worth watching'));
      expect(
        pattern.chips,
        isNot(containsAll(['same feeling', 'same situation', 'same time of day'])),
      );
    });

    test('capacity watch-next copy blocked without grounded evidence', () async {
      final entries = [
        _textEntry('1', testOne),
        _textEntry('2', testTwo),
      ];
      final hypothesis = await const PatternHypothesisEngine().build(entries);
      expect(hypothesis.watchNext.toLowerCase(), isNot(contains('capacity')));
      expect(hypothesis.watchNext.toLowerCase(), isNot(contains('saying yes')));
      expect(
        hypothesis.evidenceSoFar.any((e) => e.contains('same feeling')),
        isFalse,
      );
    });
  });

  test('mixed real + generic uses only real for hypothesis', () async {
    final entries = [
      _textEntry('1', testOne),
      _textEntry(
        '2',
        'I felt pressure to say yes again before checking my capacity today.',
      ),
    ];
    expect(ArchiveEvidenceQualityGate.allowsPatternHypothesis(entries), isFalse);
    final hypothesis = await const PatternHypothesisEngine().build(entries);
    expect(hypothesis.hasEnoughData, isFalse);
  });
}
