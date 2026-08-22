import 'package:archiveme_mobile/features/post_save_insight/selected_signal_model.dart';
import 'package:archiveme_mobile/features/signal_archive/signal_evidence_engine.dart';
import 'package:archiveme_mobile/features/signal_archive/signal_evidence_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  String observation = '',
  DateTime? createdAt,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6, 1, 12),
    transcript: transcript,
    durationSeconds: 40,
    reflection: Reflection(
      mood: 'neutral',
      emotionalIntensity: 3,
      recurringThemes: const [],
      exactLanguagePattern: '',
      concreteObservation: observation,
      repeatedSignal: '',
    ),
  );
}

SelectedSignalRecord _signal({String? entryId}) {
  return SelectedSignalRecord(
    id: 'sig1',
    title: 'Saying yes before checking capacity',
    categoryId: 'pressure',
    strengthLabel: 'Early signal',
    nextPrompt: 'When did you last say yes while already stretched?',
    savedAt: DateTime(2026, 6, 2),
    entryId: entryId,
    evidenceChips: const ['pressure', 'yes'],
    mightMean: 'You may be agreeing before you have room.',
    wouldConfirm: 'Another moment where you say yes while already full.',
    wouldContradict: 'If you pause and feel ease when you say no.',
    evidenceUsed: 'You mentioned pressure and saying yes.',
  );
}

void main() {
  test('empty signal yields needs more evidence', () {
    const engine = SignalEvidenceEngine();
    final trail = engine.build(signal: null, entries: const []);
    expect(trail.needsMoreEvidence, isTrue);
    expect(trail.items, isEmpty);
  });

  test('single origin moment needs more evidence', () {
    const engine = SignalEvidenceEngine();
    final entries = [
      _entry(
        id: 'e1',
        transcript: 'I felt pressure to say yes again today at work.',
        observation: 'Pressure before saying yes at work.',
      ),
    ];
    final trail = engine.build(
      signal: _signal(entryId: 'e1'),
      entries: entries,
    );
    expect(trail.needsMoreEvidence, isTrue);
    expect(trail.items.length, 1);
    expect(trail.items.first.relation, SignalEvidenceRelation.supports);
    expect(trail.items.first.excerpt, isNot(contains('I felt pressure')));
    expect(trail.items.first.excerpt.length, lessThan(100));
  });

  test('supporting and contradicting labels when present', () {
    const engine = SignalEvidenceEngine();
    final entries = [
      _entry(
        id: 'e1',
        createdAt: DateTime(2026, 6),
        transcript: 'I felt pressure to say yes again today at work.',
        observation: 'Pressure before saying yes at work.',
      ),
      _entry(
        id: 'e2',
        createdAt: DateTime(2026, 6, 2),
        transcript:
            'More pressure to say yes when I was already stretched thin.',
        observation: 'More pressure to say yes while stretched.',
      ),
      _entry(
        id: 'e3',
        createdAt: DateTime(2026, 6, 3),
        transcript:
            'Today I paused before answering and said no with ease when asked.',
        observation: 'Paused and said no with ease.',
      ),
    ];
    final trail = engine.build(
      signal: _signal(entryId: 'e1'),
      entries: entries,
    );
    expect(trail.needsMoreEvidence, isFalse);
    expect(trail.supportingItems.length, greaterThanOrEqualTo(2));
    expect(trail.contradictingItems, isNotEmpty);
    expect(trail.contradictingItems.first.relation.label, 'Might contradict');
  });

  test('copy constants avoid banned phrases', () {
    const banned = [
      'VoiceMemory listens',
      'diagnosis',
      'therapy',
      'coach',
      'AI friend',
    ];
    final copy = [
      ConsumerUiCopy.signalDetailEmptyTitle,
      ConsumerUiCopy.signalDetailThinksMayBe,
      ConsumerUiCopy.archiveWatchingTitle,
      ConsumerUiCopy.archiveHomeTitle,
      ConsumerUiCopy.signalCorrectionsNote,
    ].join(' ').toLowerCase();
    for (final phrase in banned) {
      expect(copy, isNot(contains(phrase.toLowerCase())));
    }
  });
}