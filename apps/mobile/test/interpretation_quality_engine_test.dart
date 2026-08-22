import 'package:archiveme_mobile/features/interpretation/interpretation_quality_engine.dart';
import 'package:archiveme_mobile/features/interpretation/interpretation_read_model.dart';
import 'package:archiveme_mobile/features/post_save_insight/signal_feedback_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry(String id, String transcript) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6, int.parse(id)),
    transcript: transcript,
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

void main() {
  const engine = InterpretationQualityEngine();

  test('saying yes / pressure / capacity yields specific read', () {
    final result = engine.build(
      latestEntry: _entry(
        '1',
        'I said yes to something I did not have time for, and now I feel pressure.',
      ),
    );

    expect(result.reads, isNotEmpty);
    final top = result.reads.first;
    expect(
      top.title.toLowerCase(),
      anyOf(
        contains('saying yes'),
        contains('capacity'),
        contains('responsibility'),
      ),
    );
    expect(
      top.nextEvidencePrompt.toLowerCase(),
      anyOf(contains('yes'), contains('capacity'), contains('agree')),
    );
    expect(top.whatWouldConfirm, isNotEmpty);
    expect(top.whatWouldContradict, isNotEmpty);
    expect(top.specificityLevel, isNot(InterpretationSpecificityLevel.low));
  });

  test('disappointing someone connects to capacity read', () {
    final prior = _entry(
      '1',
      'I said yes again even though I was already tired from work today.',
    );
    final latest = _entry(
      '2',
      'I agreed to help again because I did not want to disappoint them.',
    );

    final result = engine.build(latestEntry: latest, priorEntries: [prior]);

    expect(result.reads, isNotEmpty);
    expect(
      result.reads.first.title.toLowerCase(),
      anyOf(
        contains('disappoint'),
        contains('saying yes'),
        contains('capacity'),
      ),
    );
  });

  test('proving enough read for achievement language', () {
    final result = engine.build(
      latestEntry: _entry(
        '1',
        'I keep trying to do more because otherwise I feel like I am falling behind.',
      ),
    );

    expect(result.reads.first.title.toLowerCase(), contains('prove'));
    expect(result.reads.first.title.toLowerCase(), contains('enough'));
  });

  test('avoiding direct conversation read', () {
    final result = engine.build(
      latestEntry: _entry(
        '1',
        'I keep avoiding telling them what I actually need.',
      ),
    );

    expect(
      result.reads.first.title.toLowerCase(),
      contains('avoiding a direct conversation'),
    );
  });

  test('low specificity asks for clearer moment', () {
    final result = engine.build(
      latestEntry: _entry('1', 'I feel weird today.'),
    );

    expect(result.needsClearerMoment, isTrue);
    expect(
      result.clearerMomentPrompt?.toLowerCase(),
      contains('what happened'),
    );
    expect(result.reads, isEmpty);
  });

  test('rejected signal lowers rank of control read', () {
    const controlTitle = 'Trying to stay in control before you feel safe';
    final without = engine.build(
      latestEntry: _entry(
        '1',
        'I need to stay in control and plan everything before I feel safe.',
      ),
    );
    final withReject = engine.build(
      latestEntry: _entry(
        '2',
        'I need to stay in control and plan everything before I feel safe.',
      ),
      feedback: [
        PostSaveSignalFeedback(
          id: '1',
          signalId: 'stay_in_control',
          signalTitle: controlTitle,
          action: PostSaveSignalAction.rejected,
          createdAt: DateTime(2026, 6),
        ),
      ],
    );

    expect(without.reads.first.title, controlTitle);
    if (withReject.reads.length > 1) {
      expect(withReject.reads.first.title, isNot(controlTitle));
    }
  });

  test('archive repeat strengthens to Possible repeat or higher', () {
    final result = engine.build(
      latestEntry: _entry(
        '2',
        'I agreed to help again because I did not want to disappoint them.',
      ),
      priorEntries: [
        _entry(
          '1',
          'I said yes to something I did not have time for, and now I feel pressure.',
        ),
      ],
    );

    expect(result.archiveRepeatDetected, isTrue);
    expect(
      result.reads.first.strengthLabel,
      anyOf('Possible repeat', 'Getting clearer', 'Strong pattern'),
    );
  });

  test('reads avoid banned language', () {
    final result = engine.build(
      latestEntry: _entry(
        '1',
        'I said yes to something I did not have time for, and now I feel pressure.',
      ),
    );

    for (final read in result.reads) {
      final blob =
          '${read.title} ${read.shortRead} ${read.mightMean} ${read.whatWouldConfirm}'
              .toLowerCase();
      expect(blob, isNot(contains('voicememory')));
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('coach')));
      expect(blob, isNot(contains('ai friend')));
      expect(blob, isNot(contains('cloud processing')));
      expect(blob, isNot(contains('%')));
    }
  });

  test('alternatives are plausible competing reads', () {
    final alts = engine.alternativesFor(
      primaryReadId: 'saying_yes_capacity',
      normalizedText:
          'i said yes to something i did not have time for, and now i feel pressure.',
      tags: const ['saying yes', 'pressure'],
    );

    expect(alts, isNotEmpty);
    expect(alts.length, lessThanOrEqualTo(2));
    for (final alt in alts) {
      expect(
        alt.title.toLowerCase(),
        isNot(contains('saying yes before checking')),
      );
    }
  });
}