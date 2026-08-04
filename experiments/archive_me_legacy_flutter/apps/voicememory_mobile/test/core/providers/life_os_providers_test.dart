import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/core/providers/life_os_providers.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/services/app_services_providers.dart';
import 'package:voicememory_mobile/services/journal_service.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test('required providers compose one deterministic evidence graph', () async {
    final directory = Directory.systemTemp.createTempSync('life_os_provider_');
    addTearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    final store = await JournalStore.open(
      '${directory.path}/journal.json',
      encryptAtRest: false,
    );
    final now = DateTime.now().toUtc();
    await store.replaceAll([
      _entry(
        id: 'entry-b',
        createdAt: now.subtract(const Duration(days: 29)),
        transcript: 'I usually write plans. This chapter is startup work.',
      ),
      _entry(
        id: 'entry-a',
        createdAt: now.subtract(const Duration(days: 30)),
        transcript: 'I want to build a company. This chapter is startup work.',
      ),
    ]);
    final entries = await store.loadAll();
    final graphStore = PersonalKnowledgeGraphStore(
      storage: EncryptedJsonFileStore(
        file: File('${directory.path}/knowledge_graph.enc'),
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      ),
    );
    final semanticStore = LocalSemanticStore(
      storage: EncryptedJsonFileStore(
        file: File('${directory.path}/local_semantic.enc'),
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        journalServiceProvider.overrideWithValue(JournalService(store)),
        journalEntriesStreamProvider.overrideWith((_) => Stream.value(entries)),
        personalKnowledgeGraphStoreProvider.overrideWithValue(graphStore),
        localSemanticStoreProvider.overrideWithValue(semanticStore),
      ],
    );
    addTearDown(container.dispose);
    final graphSubscription = container.listen(
      knowledgeGraphProvider,
      (_, _) {},
    );
    addTearDown(graphSubscription.close);

    final graph = await container.read(knowledgeGraphProvider.future);
    final story = await container.read(lifeStoryProvider.future);
    final timeMachine = await container.read(aiTimeMachineProvider.future);
    final coach = await container.read(evidenceCoachProvider.future);

    expect(graph.nodes, isNotEmpty);
    expect(identical(story.graph, graph), isTrue);
    expect(identical(timeMachine.graph, graph), isTrue);
    expect(identical(coach.graph, graph), isTrue);
    expect(story.build().chapters, isNotEmpty);
    expect(timeMachine.query('one month ago').snapshots, isNotEmpty);
    expect(coach.find(), isNotEmpty);

    container.invalidate(knowledgeGraphProvider);
    final rebuilt = await container.read(knowledgeGraphProvider.future);
    expect(rebuilt.toJson(), graph.toJson());
  });
}

JournalEntry _entry({
  required String id,
  required DateTime createdAt,
  required String transcript,
}) => JournalEntry(
  id: id,
  createdAt: createdAt,
  transcript: transcript,
  durationSeconds: 0,
  reflection: const Reflection(
    mood: '',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);
