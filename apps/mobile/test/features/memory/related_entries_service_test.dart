import 'package:archiveme_mobile/features/memory/entry_embedding_store.dart';
import 'package:archiveme_mobile/features/memory/related_entries_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../storage/sqlite/support/configure_sqlite_test_ffi.dart';

void main() {
  setUpAll(configureSqliteTestFfi);

  final now = DateTime.utc(2026, 9, 26);

  JournalEntry saved({
    required String id,
    required String transcript,
    required DateTime createdAt,
    String? audioPath,
  }) {
    return JournalEntry(
      id: id,
      createdAt: createdAt,
      transcript: transcript,
      durationSeconds: 8,
      localAudioPath: audioPath,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );
  }

  List<double> axis(int hot) {
    return [
      for (var i = 0; i < EntryEmbeddingStore.dimensions; i++) i == hot ? 1.0 : 0.0,
    ];
  }

  test('related entries skip recent, deleted, and hidden moments', () async {
    final db = await openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    final store = EntryEmbeddingStore(db);
    final query = axis(0);
    final old = now.subtract(const Duration(days: 21));
    final recent = now.subtract(const Duration(days: 2));
    final match = saved(
      id: 'older-match',
      transcript: 'I walked by the river. The kitchen was quiet.',
      createdAt: old,
      audioPath: '/tmp/river.m4a',
    );
    final tooSoon = saved(
      id: 'recent',
      transcript: 'I walked by the river.',
      createdAt: recent,
    );
    final removed = saved(
      id: 'deleted',
      transcript: 'I walked by the river.',
      createdAt: old,
    ).markDeleted();
    final hidden = saved(
      id: 'hidden',
      transcript: 'I walked by the river.',
      createdAt: old,
    );
    final different = saved(
      id: 'other-topic',
      transcript: 'The train was late.',
      createdAt: old,
    );

    final service = RelatedEntriesService(store);
    final matches = service.select(
      query: query,
      currentId: 'today',
      hiddenEntryIds: {'hidden'},
      now: now,
      embed: (text) => text.contains('river') ? axis(0) : axis(1),
      wordTimestamps: (entry) => entry.id == 'older-match'
          ? [(word: 'river', startSeconds: 12)]
          : null,
      candidates: [
        (entry: match, vector: axis(0)),
        (entry: tooSoon, vector: axis(0)),
        (entry: removed, vector: axis(0)),
        (entry: hidden, vector: axis(0)),
        (entry: different, vector: axis(1)),
      ],
    );

    expect(matches.map((match) => match.id), ['older-match']);
    expect(matches.single.quote, 'I walked by the river.');
    expect(matches.single.startSeconds, 12);
    expect(matches.single.localAudioPath, '/tmp/river.m4a');
  });
}
