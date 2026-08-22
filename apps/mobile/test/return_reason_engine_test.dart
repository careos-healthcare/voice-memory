import 'package:archiveme_mobile/features/discover/discover_cache.dart';
import 'package:archiveme_mobile/features/return_reason/return_reason_coordinator.dart';
import 'package:archiveme_mobile/features/return_reason/return_reason_engine.dart';
import 'package:archiveme_mobile/features/return_reason/return_reason_models.dart';
import 'package:archiveme_mobile/features/return_reason/return_reason_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

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
  setUp(() {
    DiscoverYourselfCache.instance.invalidate();
  });

  test('uncertain patterns card lists genuine low-frequency themes', () {
    final entries = <JournalEntry>[
      _entry(
        id: 'c1',
        at: DateTime(2026, 3),
        line: 'Career confidence reflection one',
        themes: const ['career'],
      ),
      _entry(
        id: 'c2',
        at: DateTime(2026, 3, 2),
        line: 'Career confidence reflection two',
        themes: const ['career'],
      ),
      _entry(
        id: 'r1',
        at: DateTime(2026, 4),
        line: 'Relationships with partner and family today',
        themes: const ['relationship'],
      ),
      _entry(
        id: 'r2',
        at: DateTime(2026, 4, 2),
        line: 'Relationships with partner and family again',
        themes: const ['relationship'],
      ),
      _entry(
        id: 'x1',
        at: DateTime(2026, 5),
        line: 'General reflection about confidence and growth',
        themes: const ['confidence'],
      ),
      _entry(
        id: 'x2',
        at: DateTime(2026, 5, 2),
        line: 'Another reflection about confidence and growth',
        themes: const ['confidence'],
      ),
    ];

    final card = const ReturnReasonEngine().build(entries: entries);
    expect(card, isNotNull);
    expect(card!.kind, ReturnReasonKind.uncertainPatterns);
    expect(card.state.unresolvedPatterns.length, greaterThanOrEqualTo(2));
    expect(card.bodyLines.any((l) => l.contains('uncertain')), isTrue);
  });

  test('conflicting evidence card when contradiction exists', () {
    final entries = <JournalEntry>[
      _entry(
        id: 'old',
        at: DateTime(2025, 1, 10),
        line: 'I hate networking events',
        themes: const ['networking'],
      ),
      _entry(
        id: 'new',
        at: DateTime(2026, 2),
        line: 'Networking changed my career',
        themes: const ['networking', 'career'],
      ),
      ...List.generate(
        4,
        (i) => _entry(
          id: 'pad$i',
          at: DateTime(2025, 6, i + 1),
          line: 'Neutral filler reflection with enough transcript text.',
        ),
      ),
    ];

    final card = const ReturnReasonEngine().build(entries: entries);
    expect(card, isNotNull);
    expect(card!.kind, ReturnReasonKind.conflictingEvidence);
    expect(
      card.bodyLines.any((l) => l.contains('conflicting evidence')),
      isTrue,
    );
    expect(card.beliefQuote, isNotNull);
  });

  test('state round-trips through store', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    await AppServices.resetForTest(
      journalPath: '/tmp/vm_return_$stamp.json',
      prefsPath: '/tmp/vm_return_prefs_$stamp.json',
    );

    final state = ReturnReasonState(
      pendingQuestions: const ['Whether belief is stable'],
      unresolvedPatterns: const ['Confidence', 'Relationships'],
      emergingBeliefs: const [],
      generatedAt: DateTime(2026, 5),
      primaryMessage: 'Uncertain',
      kind: 'uncertainPatterns',
      recordingsNeeded: 2,
    );

    final store = ReturnReasonStore(AppServices.instance.prefs);
    await store.write(state);
    final read = await store.read();
    expect(read?.unresolvedPatterns, ['Confidence', 'Relationships']);
    expect(read?.pendingQuestions.first, contains('stable'));
  });

  test('coordinator restores card from persisted state', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    await AppServices.resetForTest(
      journalPath: '/tmp/vm_return_coord_$stamp.json',
      prefsPath: '/tmp/vm_return_coord_prefs_$stamp.json',
    );

    await ReturnReasonStore(AppServices.instance.prefs).write(
      ReturnReasonState(
        pendingQuestions: const [],
        unresolvedPatterns: const ['Confidence', 'Relationships'],
        emergingBeliefs: const [],
        generatedAt: DateTime(2026, 5),
        primaryMessage: 'Uncertain',
        kind: 'uncertainPatterns',
        recordingsNeeded: 2,
      ),
    );

    final store = AppServices.instance.journalStore;
    for (var i = 0; i < 5; i++) {
      await store.save(
        _entry(
          id: 'rr$i',
          at: DateTime(2026, 5, i + 1),
          line: 'Reflection about confidence and relationships $i',
        ),
      );
    }

    final card = await ReturnReasonCoordinator.loadCardForArchive();
    expect(card, isNotNull);
    expect(card!.bodyLines.any((l) => l.contains('Confidence')), isTrue);
  });
}