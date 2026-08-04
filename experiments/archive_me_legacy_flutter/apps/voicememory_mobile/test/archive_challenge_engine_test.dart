import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_challenge/archive_challenge_engine.dart';
import 'package:voicememory_mobile/features/archive_challenge/archive_challenge_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String line,
  List<String> themes = const [],
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: '$line — padding for evidence threshold in transcript body.',
    durationSeconds: 30,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 4,
      recurringThemes: themes,
      exactLanguagePattern: line,
      concreteObservation: line,
      repeatedSignal: '',
    ),
  );
}

void main() {
  setUp(() async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    await AppServices.resetForTest(
      journalPath: '/tmp/vm_challenge_$stamp.json',
      prefsPath: '/tmp/vm_challenge_prefs_$stamp.json',
    );
  });

  test('uncertainty vs failure challenge requires evidence and confidence', () {
    final entries = <JournalEntry>[
      ...List.generate(
        6,
        (i) => _entry(
          id: 'u$i',
          at: DateTime(2026, 5, i + 1),
          line: 'I feel uncertain and not sure what direction to take',
        ),
      ),
      _entry(
        id: 'f1',
        at: DateTime(2026, 5, 8),
        line: 'I worried about failure after one mistake last week',
      ),
      ...List.generate(
        2,
        (i) => _entry(
          id: 'pad$i',
          at: DateTime(2026, 4, i + 1),
          line: 'Neutral filler reflection for evidence threshold $i',
        ),
      ),
    ];

    const engine = ArchiveChallengeEngine();
    final challenge = engine.detectChallenge(entries: entries);
    expect(challenge, isNotNull);
    expect(
      challenge!.confidence,
      greaterThanOrEqualTo(ArchiveChallengeEngine.minConfidence),
    );
    expect(
      challenge.evidenceEntryIds.length,
      greaterThanOrEqualTo(ArchiveChallengeEngine.minEvidenceCount),
    );
    expect(challenge.headline.toLowerCase(), contains('uncertainty'));
  });

  test('returns null below evidence threshold', () {
    final entries = List.generate(
      3,
      (i) => _entry(
        id: 'e$i',
        at: DateTime(2026, 3, i + 1),
        line: 'Short reflection $i',
      ),
    );
    expect(
      const ArchiveChallengeEngine().detectChallenge(entries: entries),
      isNull,
    );
  });

  test('store keeps at most one active challenge', () async {
    final store = ArchiveChallengeStore(AppServices.instance.prefs);
    final entries = <JournalEntry>[
      ...List.generate(
        6,
        (i) => _entry(
          id: 's$i',
          at: DateTime(2026, 3, i + 1),
          line: 'I feel uncertain and not sure about the path ahead $i',
        ),
      ),
      _entry(
        id: 'sf',
        at: DateTime(2026, 3, 10),
        line: 'I worried about failure after one mistake last week',
      ),
      _entry(
        id: 'sp',
        at: DateTime(2026, 3, 11),
        line: 'Neutral filler reflection for evidence threshold padding',
      ),
    ];

    const engine = ArchiveChallengeEngine();
    final first = await engine.loadActiveChallenge(
      store: store,
      entries: entries,
    );
    expect(first, isNotNull);

    final again = await engine.loadActiveChallenge(
      store: store,
      entries: entries,
    );
    expect(again?.id, first?.id);
  });
}
