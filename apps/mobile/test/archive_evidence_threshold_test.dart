import 'package:archiveme_mobile/features/archive_evidence/archive_belief_correction_store.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_entry_signal_guard.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_threshold.dart';
import 'package:archiveme_mobile/features/archive_thought_map/archive_thought_map_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

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

List<JournalEntry> _repeatPressureEntries() => [
  _entry(
    id: 'a',
    transcript:
        'I had no capacity but I said yes again to the extra meeting today.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _entry(
    id: 'b',
    transcript:
        'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    id: 'c',
    transcript:
        'I said yes again even though I had no capacity for one more ask.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

List<JournalEntry> _unrelatedEntries() => [
  _entry(
    id: 'w',
    transcript:
        'Work deadline stress piled up and I stayed late finishing slides.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _entry(
    id: 'h',
    transcript:
        'Health worry kept me up — doctor appointment next week feels heavy.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    id: 'f',
    transcript:
        'Family tension at dinner — partner and I talked past each other.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

const _bannedPhrases = [
  'therapy',
  'diagnosis',
  'mental health score',
  'brain mapping',
  'treatment',
  'archiveme knows',
];

void main() {
  setUp(ArchiveBeliefCorrectionStore.resetForTest);

  group('ArchiveEvidenceThreshold', () {
    test('one meaningful entry does not produce a named pattern', () {
      final result = ArchiveEvidenceThreshold.evaluate([
        _entry(
          id: 'one',
          transcript: 'Only one saved moment with enough transcript length.',
        ),
      ]);
      expect(result.canNameThread, isFalse);
      expect(result.stage, ArchivePatternStage.stillForming);
      expect(result.showFormingFallback, isTrue);
    });

    test('two meaningful entries does not overclaim', () {
      final entries = _repeatPressureEntries().take(2).toList();
      final result = ArchiveEvidenceThreshold.evaluate(entries);
      expect(result.canNameThread, isFalse);
      expect(result.meaningfulEntryCount, 2);
      expect(result.stage, ArchivePatternStage.stillForming);
    });

    test('three unrelated themes shows forming fallback', () {
      final result = ArchiveEvidenceThreshold.evaluate(_unrelatedEntries());
      expect(result.canNameThread, isFalse);
      expect(result.showFormingFallback, isTrue);
      expect(result.stage, ArchivePatternStage.stillForming);
    });

    test('three repeated pressure entries shows repeated thread', () {
      final result = ArchiveEvidenceThreshold.evaluate(
        _repeatPressureEntries(),
      );
      expect(result.canNameThread, isTrue);
      expect(result.sharedThemeEntryCount, greaterThanOrEqualTo(2));
      expect(result.snippetCount, greaterThanOrEqualTo(2));
      expect(result.hasRepeatedSignal, isTrue);
      expect(
        result.stage,
        anyOf(
          ArchivePatternStage.repeatedThread,
          ArchivePatternStage.strongPattern,
          ArchivePatternStage.earlySignal,
        ),
      );
      expect(result.stage.label, isNot(contains('%')));
    });

    test('low-signal Test entries are excluded from evidence count', () {
      final entries = [
        ..._repeatPressureEntries(),
        _entry(id: 'low', transcript: 'Test'),
      ];
      expect(ArchiveEntrySignalGuard.isLowSignalText('Test'), isTrue);
      expect(ArchiveEvidenceThreshold.meaningfulEntryCount(entries), 3);
    });

    test('named thread requires at least two evidence snippets', () {
      final result = ArchiveEvidenceThreshold.evaluate(
        _repeatPressureEntries(),
      );
      expect(result.snippetCount, greaterThanOrEqualTo(2));
      expect(result.canNameThread, isTrue);

      const engine = ArchiveThoughtMapEngine();
      final preview = engine.build(_repeatPressureEntries());
      final totalSnippets = preview.nodes.fold<int>(
        0,
        (sum, node) => sum + node.snippets.length,
      );
      expect(totalSnippets, greaterThanOrEqualTo(2));
    });

    test('Not quite suppresses the same thread', () {
      const engine = ArchiveThoughtMapEngine();
      final entries = _repeatPressureEntries();
      final preview = engine.build(entries);
      expect(preview.shouldShow, isTrue);

      ArchiveBeliefCorrectionStore.dismiss(preview.suggestionId);
      final suppressed = engine.build(entries);
      expect(suppressed.shouldShow, isFalse);

      final threshold = ArchiveEvidenceThreshold.evaluate(
        entries,
        suggestionId: preview.suggestionId,
      );
      expect(threshold.suppressedByCorrection, isTrue);
      expect(threshold.canNameThread, isFalse);
    });

    test('This feels right allows thread to remain visible at threshold', () {
      const engine = ArchiveThoughtMapEngine();
      final entries = _repeatPressureEntries();
      final preview = engine.build(entries);
      ArchiveBeliefCorrectionStore.markSaved(preview.suggestionId);

      final rebuilt = engine.build(entries);
      expect(rebuilt.shouldShow, isTrue);

      final threshold = ArchiveEvidenceThreshold.evaluate(
        entries,
        suggestionId: preview.suggestionId,
      );
      expect(threshold.boostedByCorrection, isTrue);
    });

    test('confidence labels are non-numeric and safe', () {
      for (final stage in ArchivePatternStage.values) {
        expect(stage.label, isNot(contains('%')));
        expect(stage.label, isNot(contains('score')));
        for (final banned in _bannedPhrases) {
          expect(
            stage.label.toLowerCase(),
            isNot(contains(banned)),
            reason: stage.label,
          );
        }
      }
    });

    test('forming copy matches product wedge', () {
      expect(
        ArchiveEvidenceThreshold.formingTitle,
        'Your mind map is still forming',
      );
      expect(
        ArchiveEvidenceThreshold.formingBody,
        contains('name this thread'),
      );
    });
  });
}