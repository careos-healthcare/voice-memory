import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/search/local_vector_search_engine.dart';
import 'package:voicememory_mobile/features/archive_semantic_search/archive_semantic_query_parser.dart';
import 'package:voicememory_mobile/features/archive_semantic_search/archive_semantic_search_engine.dart';
import 'package:voicememory_mobile/features/archive_semantic_search/semantic_index_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test('hashed embeddings are deterministic and connect semantic aliases', () {
    const driver = HashedLocalEmbeddingDriver();
    expect(driver.embed('same text'), orderedEquals(driver.embed('same text')));
    expect(
      LocalVectorSearchEngine.cosineSimilarity(
        driver.embed('work burnout'),
        driver.embed('exhausted after deadlines at my job'),
      ),
      greaterThan(0),
    );
  });

  test('parser identifies enumeration, mood, and temporal hints', () {
    final parser = ArchiveSemanticQueryParser(
      now: () => DateTime.utc(2026, 7, 26),
    );
    final enumeration = parser.parse(
      'Show me every time I mentioned work burnout last week',
    );
    expect(enumeration.intent.name, 'topicEnumeration');
    expect(enumeration.concepts, containsAll(['work', 'burnout']));
    expect(enumeration.after, DateTime.utc(2026, 7, 19));

    final mood = parser.parse('When was I happiest?');
    expect(mood.intent.name, 'happiest');
  });

  group('encrypted semantic index', () {
    late Directory directory;
    late EncryptedJsonFileStore encrypted;
    late _CountingDriver driver;
    late SemanticIndexStore index;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('semantic_index_test');
      encrypted = EncryptedJsonFileStore(
        file: File('${directory.path}/semantic_archive_index.enc'),
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      );
      driver = _CountingDriver();
      index = SemanticIndexStore(storage: encrypted, embeddingDriver: driver);
    });

    tearDown(() async {
      await index.dispose();
      await directory.delete(recursive: true);
    });

    test(
      'incrementally creates, skips, updates, deletes, and omits text',
      () async {
        final first = _entry('one', 'private transcript needle');
        await index.reconcile([first]);
        expect(driver.calls, 1);
        await index.reconcile([first]);
        expect(driver.calls, 1);

        final changed = _entry('one', 'changed private transcript');
        await index.reconcile([changed]);
        expect(driver.calls, 2);
        await index.reconcile(const []);
        expect((await index.loadSnapshot()).vectors, isEmpty);

        final disk = await encrypted.file.readAsString();
        expect(disk, isNot(contains('private transcript needle')));
        expect(disk, isNot(contains('changed private transcript')));
        expect(disk, isNot(contains('query')));
      },
    );

    test(
      'serializes concurrent writes and rebuilds corrupt payloads',
      () async {
        final one = _entry('one', 'work deadline');
        final two = _entry('two', 'calm evening');
        await Future.wait([
          index.reconcile([one]),
          index.reconcile([one, two]),
        ]);
        expect(
          (await index.loadSnapshot()).vectors.keys,
          containsAll(['one', 'two']),
        );

        await encrypted.writeJson({'schemaVersion': 1, 'entries': 'broken'});
        await index.reconcile([two]);
        expect((await index.loadSnapshot()).vectors.keys, ['two']);
      },
    );

    test('rebuilds on schema change and supports explicit clear', () async {
      final entry = _entry('one', 'private work thought');
      await index.reconcile([entry]);
      await index.dispose();
      driver = _CountingDriver();
      index = SemanticIndexStore(
        storage: encrypted,
        embeddingDriver: driver,
        schemaVersion: 2,
      );
      await index.reconcile([entry]);
      expect(driver.calls, 1);
      await index.clear();
      expect(await encrypted.file.exists(), isFalse);
    });
  });

  group('entry-level hybrid search', () {
    late Directory directory;
    late JournalStore journal;
    late SemanticIndexStore index;
    late ArchiveSemanticSearchEngine engine;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('semantic_search_test');
      journal = await JournalStore.open(
        '${directory.path}/journal.json',
        encryptAtRest: false,
      );
      index = SemanticIndexStore(
        storage: EncryptedJsonFileStore(
          file: File('${directory.path}/index.enc'),
          keyStore: InMemoryPrivateDataEncryptionKeyStore(),
        ),
      );
      engine = ArchiveSemanticSearchEngine(
        journalStore: journal,
        indexStore: index,
      );
    });

    tearDown(() async {
      engine.dispose();
      await index.dispose();
      await directory.delete(recursive: true);
    });

    test(
      'enumerates grounded multi-concept aliases and never returns stale IDs',
      () async {
        await journal.replaceAll([
          _entry('match', 'I was exhausted after deadlines at work.'),
          _entry('partial', 'Work was productive today.'),
        ]);
        final page = await engine.search(
          'show me every time I mentioned work burnout',
        );
        expect(page.results.map((result) => result.entryId), ['match']);
        expect(
          page.results.single.snippet.toLowerCase(),
          contains('exhausted'),
        );

        await journal.delete('match');
        final afterDelete = await engine.search('work burnout');
        expect(
          afterDelete.results.map((result) => result.entryId),
          isNot(contains('match')),
        );
      },
    );

    test('returns exact UTF-16 evidence offsets around emoji', () async {
      const transcript = 'Morning 😀 then I felt joyful at lunch.';
      await journal.save(_entry('emoji', transcript));
      final result = (await engine.search('joyful')).results.single;
      expect(
        transcript.substring(
          result.evidenceStartUtf16,
          result.evidenceEndUtf16,
        ),
        'joyful',
      );
      expect(
        result.snippet.substring(
          result.highlightStartUtf16,
          result.highlightEndUtf16,
        ),
        'joyful',
      );
    });

    test(
      'mood superlative uses explicit mood and reports insufficient evidence',
      () async {
        await journal.replaceAll([
          _entry(
            'happy',
            'A genuinely joyful day.',
            mood: 'happy',
            intensity: 8,
          ),
          _entry('calm', 'A quiet ordinary day.', mood: 'calm', intensity: 9),
        ]);
        final happy = await engine.search('when was I happiest?');
        expect(happy.results.first.entryId, 'happy');

        final sad = await engine.search('when was I saddest?');
        expect(sad.results, isEmpty);
        expect(sad.insufficientReason, contains('not enough explicit mood'));
      },
    );

    test('applies date filters and bounded pagination', () async {
      await journal.replaceAll([
        _entry('old', 'work burnout', date: DateTime.utc(2025, 1, 1)),
        _entry('new', 'work burnout', date: DateTime.utc(2026, 7, 20)),
      ]);
      final filtered = await engine.search(
        'entries about work burnout after 2026-01-01',
        limit: 1,
      );
      expect(filtered.results.single.entryId, 'new');
      expect(filtered.hasMore, isFalse);
    });
  });

  test('implementation has no network or analytics imports', () {
    for (final path in [
      'lib/features/archive_semantic_search/archive_semantic_search_engine.dart',
      'lib/features/archive_semantic_search/semantic_index_store.dart',
      'lib/features/archive_semantic_search/archive_semantic_query_parser.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains("package:http")));
      expect(source, isNot(contains('ProductAnalytics')));
      expect(source, isNot(contains('ActivationTracker')));
    }
  });
}

JournalEntry _entry(
  String id,
  String transcript, {
  String mood = 'neutral',
  int intensity = 0,
  DateTime? date,
}) => JournalEntry(
  id: id,
  createdAt: date ?? DateTime.utc(2026, 7, 20),
  transcript: transcript,
  durationSeconds: 10,
  reflection: Reflection(
    mood: mood,
    emotionalIntensity: intensity,
    recurringThemes: const [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

final class _CountingDriver implements LocalEmbeddingDriver {
  final HashedLocalEmbeddingDriver _delegate = const HashedLocalEmbeddingDriver(
    dimensions: 64,
  );
  int calls = 0;

  @override
  int get dimensions => _delegate.dimensions;

  @override
  Float32List embed(String text) {
    calls++;
    return _delegate.embed(text);
  }
}
