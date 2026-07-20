import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/services/cognitive_analyzer.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory tempDir;
  late JournalStore store;
  late InMemoryPrivateDataEncryptionKeyStore keyStore;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('vm_journal_biomarkers_');
    keyStore = InMemoryPrivateDataEncryptionKeyStore();
    store = await JournalStore.open(
      '${tempDir.path}/entries.json',
      keyStore: keyStore,
    );
  });

  const reflection = Reflection(
    mood: 'calm',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: '',
  );

  JournalEntry entry({
    required String id,
    required String transcript,
  }) {
    return JournalEntry(
      id: id,
      createdAt: DateTime.utc(2026, 6, 12, 12),
      transcript: transcript,
      durationSeconds: 20,
      reflection: reflection,
      syncStatus: SyncStatus.localOnly,
    );
  }

  test('save attaches biomarkers derived from transcript', () async {
    const analyzer = CognitiveAnalyzer();
    const transcript = 'the the the cat sat on the mat today';

    await store.save(entry(id: 'entry_1', transcript: transcript));

    final saved = await store.getById('entry_1');
    expect(saved, isNotNull);
    expect(saved!.biomarkers, analyzer.analyzeTranscript(transcript));
  });

  test('update recomputes biomarkers when transcript changes', () async {
    const analyzer = CognitiveAnalyzer();
    const initialTranscript = 'one two three four five six';
    const updatedTranscript = 'WOW!!! NO WAY!!! STOP!!!';

    await store.save(entry(id: 'entry_1', transcript: initialTranscript));
    await store.save(entry(id: 'entry_1', transcript: updatedTranscript));

    final saved = await store.getById('entry_1');
    expect(saved?.biomarkers, analyzer.analyzeTranscript(updatedTranscript));
    expect(
      saved?.biomarkers?.emotionalVolatility,
      greaterThan(
        analyzer.analyzeTranscript(initialTranscript).emotionalVolatility,
      ),
    );
  });

  test('markSynced preserves biomarkers', () async {
    const transcript = 'One two three. Four five six. Seven eight nine.';
    await store.save(entry(id: 'entry_1', transcript: transcript));

    final before = await store.getById('entry_1');
    await store.markSynced('entry_1');

    final after = await store.getById('entry_1');
    expect(after?.syncStatus, SyncStatus.synced);
    expect(after?.biomarkers, before?.biomarkers);
  });
}
