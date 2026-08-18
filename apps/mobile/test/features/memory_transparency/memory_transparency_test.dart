import 'package:archiveme_mobile/features/archive_explanations/archive_explanation_engine.dart';
import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/memory_transparency/memory_transparency_catalog.dart';
import 'package:archiveme_mobile/features/memory_transparency/memory_transparency_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry(String id, String transcript) {
  return JournalEntry(
    id: id,
    createdAt: DateTime.utc(2026, 1, int.parse(id.replaceAll('e', ''))),
    transcript: transcript,
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'calm',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'observation',
      repeatedSignal: 'signal',
    ),
  );
}

void main() {
  setUp(() async {
    await MemoryTransparencyStore.resetForTest();
    await MemoryTransparencyStore.ensureLoaded();
  });

  test('suppressed belief insight is omitted from catalog', () async {
    await MemoryTransparencyStore.suppress(ArchiveInsightRef.belief().id);

    final records = const MemoryTransparencyCatalog().build(
      entries: List.generate(
        8,
        (i) => _entry('e${i + 1}', 'I keep saying yes at work when exhausted'),
      ),
    );

    expect(records.any((r) => r.id == 'belief'), isFalse);
  });

  test('suppressed insight does not rebuild in explanation engine', () async {
    await MemoryTransparencyStore.suppress(ArchiveInsightRef.belief().id);
    const engine = ArchiveExplanationEngine();
    final entries = List.generate(
      8,
      (i) => _entry('e${i + 1}', 'I keep saying yes at work when exhausted'),
    );

    final explanation = engine.buildExplanation(
      ref: ArchiveInsightRef.belief(),
      entries: entries,
    );

    expect(explanation, isNull);
  });
}
