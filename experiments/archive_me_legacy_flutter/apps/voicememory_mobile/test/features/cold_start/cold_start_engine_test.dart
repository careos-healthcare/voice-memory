import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/cold_start/cold_start_engine.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test('generates valid seed nodes and persists the survey graph', () async {
    final root = await Directory.systemTemp.createTemp('cold-start-engine-');
    addTearDown(() => root.delete(recursive: true));
    final prefsFile = File('${root.path}/prefs.json');
    await prefsFile.writeAsString('{}');
    final prefs = MobilePrefsStore(file: prefsFile);
    final graphStore = PersonalKnowledgeGraphStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/graph.enc'),
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      ),
    );
    final seedStore = ColdStartSeedStore(prefs);
    final engine = ColdStartEngine(
      seedStore: seedStore,
      graphStore: graphStore,
    );
    const data = ColdStartSeedData(
      people: ['Maya', 'Jordan'],
      focus: ColdStartFocus.relationships,
      goalOrChallenge: 'Listen before solving',
    );

    final generated = engine.generate(data);
    expect(generated.nodes, hasLength(4));
    expect(generated.edges, hasLength(3));
    expect(generated.nodes.every((node) => node.hasValidEvidence), isTrue);
    expect(generated.edges.every((edge) => edge.hasValidEvidence), isTrue);

    await engine.persist(data);
    expect((await graphStore.load()).nodes, hasLength(4));
    expect((await graphStore.reconcile(const [])).nodes, hasLength(4));
    expect((await seedStore.load())?.people, ['Maya', 'Jordan']);
    expect(await seedStore.isComplete(), isTrue);
  });

  test('empty optional context generates an empty valid graph', () {
    final engine = ColdStartEngine(
      seedStore: ColdStartSeedStore(
        MobilePrefsStore(file: File('test/tmp/unused-cold-start-prefs.json')),
      ),
      graphStore: PersonalKnowledgeGraphStore(
        storage: EncryptedJsonFileStore(
          file: File('test/tmp/unused-cold-start-graph.enc'),
          keyStore: InMemoryPrivateDataEncryptionKeyStore(),
        ),
      ),
    );

    final generated = engine.generate(const ColdStartSeedData());
    expect(generated.nodes, isEmpty);
    expect(generated.edges, isEmpty);
  });
}
