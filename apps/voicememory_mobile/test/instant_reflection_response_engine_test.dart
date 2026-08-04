import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/instant_reflection/instant_reflection_response.dart';
import 'package:voicememory_mobile/features/instant_reflection/instant_reflection_response_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  int intensity = 3,
  List<String> themes = const [],
  String? pattern,
  String observation = '',
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 5, 10 + id.hashCode.abs() % 10),
    transcript: transcript,
    durationSeconds: 30,
    reflection: Reflection(
      mood: 'neutral',
      emotionalIntensity: intensity,
      recurringThemes: themes,
      exactLanguagePattern: pattern ?? transcript,
      concreteObservation: observation,
      repeatedSignal: '',
    ),
  );
}

void main() {
  const engine = InstantReflectionResponseEngine();

  test('returns null for short transcript', () {
    expect(
      engine.respond(
        entry: _entry(id: '1', transcript: 'too short'),
      ),
      isNull,
    );
  });

  test('exact language outranks generic uncertainty', () {
    final r = engine.respond(
      entry: _entry(
        id: '2',
        transcript:
            'I am not sure what to do about this job and I feel uncertain today.',
      ),
    );
    expect(r?.signal, InstantReflectionSignal.specificObservation);
    expect(r?.bodyLine, contains('From this moment'));
    expect(r?.bodyLine, contains('not sure'));
  });

  test('detects importance language', () {
    final r = engine.respond(
      entry: _entry(
        id: '3',
        transcript:
            'This is really important to me and matters a lot in my life right now.',
        intensity: 4,
      ),
    );
    expect(r?.signal, InstantReflectionSignal.specificObservation);
  });

  test('quotes exact phrase with observable micro-habit', () {
    final r = engine.respond(
      entry: _entry(
        id: 'habit',
        transcript:
            'When Slack pings late, I say yes before checking my calendar.',
        pattern: 'say yes before checking my calendar',
        observation:
            'When Slack pings late, you say yes before checking your calendar.',
      ),
    );
    expect(r?.signal, InstantReflectionSignal.specificObservation);
    expect(r?.bodyLine, contains('“say yes before checking my calendar”'));
    expect(r?.bodyLine, contains('When Slack pings late'));
  });

  test('exact cross-entry phrase outranks a generic topic', () {
    final prior = _entry(
      id: 'prior',
      transcript:
          'Yesterday I said yes before checking my calendar and had no room.',
      pattern: 'said yes before checking my calendar',
    );
    final current = _entry(
      id: 'current',
      transcript:
          'Today I said yes before checking my calendar when work called.',
      pattern: 'said yes before checking my calendar',
    );
    final r = engine.respond(entry: current, priorEntries: [prior]);
    expect(r?.signal, InstantReflectionSignal.repeatedPhrase);
    expect(r?.bodyLine, contains('Early signal from 2 moments'));
    expect(r?.bodyLine, contains('“said yes”'));
  });

  test('detects repeated topic across archive', () {
    final prior = List.generate(
      3,
      (i) => _entry(
        id: 'p$i',
        transcript:
            'Work stress at the office keeps coming up in my daily reflections $i.',
        themes: const ['career'],
        pattern: '',
      ),
    );
    final r = engine.respond(
      entry: _entry(
        id: 'c',
        transcript:
            'Another long day at work with career pressure and office stress.',
        themes: const ['career'],
        pattern: '',
      ),
      priorEntries: prior,
    );
    expect(r?.signal, InstantReflectionSignal.repeatedTopic);
  });

  test('listening line when no pattern matched', () {
    final r = engine.respond(
      entry: _entry(
        id: '4',
        transcript:
            'Today I walked in the park and watched the clouds for a while peacefully.',
        pattern: '',
      ),
    );
    expect(r?.signal, InstantReflectionSignal.listening);
  });
}
