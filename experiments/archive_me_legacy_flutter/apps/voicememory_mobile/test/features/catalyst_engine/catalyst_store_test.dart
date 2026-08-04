import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/features/catalyst_engine/catalyst_models.dart';
import 'package:voicememory_mobile/features/catalyst_engine/catalyst_store.dart';
import 'package:voicememory_mobile/features/catalyst_engine/catalyst_templates.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test('round-trips recipes through encrypted local storage', () async {
    final root = Directory.systemTemp.createTempSync('catalyst-store-');
    final file = File('${root.path}/catalyst.enc');
    final store = CatalystStore(
      EncryptedJsonFileStore(
        file: file,
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      ),
    );
    try {
      await store.saveRecipe(CatalystTemplates.morningCouncil);
      final state = await store.read();

      expect(state.recipes.single.name, 'Morning Council Dispatch');
      expect(
        await EncryptedJsonFileStore.fileOmitsPlaintextNeedle(
          file,
          'Morning Council Dispatch',
        ),
        isTrue,
      );
    } finally {
      await store.dispose();
      root.deleteSync(recursive: true);
    }
  });

  test('graph node tags are normalized and backward compatible', () {
    final node = GraphNode(
      type: NodeType.memory,
      label: 'Catalyst memory',
      confidence: 1,
      origin: NodeOrigin.manual,
      tags: const [' Focus ', 'focus', 'Private'],
    );

    final restored = GraphNode.fromJson(node.toJson());
    final legacy = GraphNode.fromJson({...node.toJson()}..remove('tags'));

    expect(restored.tags, {'focus', 'private'});
    expect(legacy.tags, isEmpty);
  });

  test('rejects duplicate action ids and oversized recipes', () {
    expect(
      () => CatalystRecipe(
        id: 'bad',
        name: 'Bad',
        trigger: const CatalystTrigger(CatalystTriggerKind.manual),
        actions: const [
          CatalystAction(id: 'same', kind: CatalystActionKind.rebuildClusters),
          CatalystAction(id: 'same', kind: CatalystActionKind.museSweep),
        ],
      ),
      throwsFormatException,
    );
  });
}
