import 'dart:typed_data';

import 'package:archiveme_crypto/archiveme_crypto.dart';
import 'package:test/test.dart';

import 'support/recording_key_material_store.dart';

void main() {
  group('KeyMaterialStore contract (host fake)', () {
    late RecordingKeyMaterialStore store;

    setUp(() {
      store = RecordingKeyMaterialStore();
    });

    test('write then read returns a copy of the raw material', () async {
      final material = freshKeyBytes(fill: 0x11);
      await store.writeKey('logical.alpha', material);
      material[0] = 0xff;

      final read = await store.readKey('logical.alpha');
      expect(read, isNotNull);
      expect(read, isNot(same(material)));
      expect(read!.first, 0x11);
      expect(store.reads, ['logical.alpha']);
      expect(store.writes, ['logical.alpha']);
    });

    test('read of a missing key is null', () async {
      expect(await store.readKey('never-written'), isNull);
    });

    test('delete removes only that logical key', () async {
      await store.writeKey('keep', freshKeyBytes(fill: 0x21));
      await store.writeKey('drop', freshKeyBytes(fill: 0x22));
      await store.deleteKey('drop');

      expect(await store.readKey('keep'), freshKeyBytes(fill: 0x21));
      expect(await store.readKey('drop'), isNull);
      expect(store.deletes, ['drop']);
    });

    test('keys are isolated — writing beta does not change alpha', () async {
      await store.writeKey('alpha', freshKeyBytes(fill: 0x31));
      await store.writeKey('beta', freshKeyBytes(fill: 0x32));
      expect(await store.readKey('alpha'), freshKeyBytes(fill: 0x31));
      expect(await store.readKey('beta'), freshKeyBytes(fill: 0x32));
    });
  });

  group('MemoryKeyMaterialStore', () {
    test('round-trips, isolates keys, and delete is a no-op when missing', () async {
      final store = MemoryKeyMaterialStore();
      final first = Uint8List.fromList(List<int>.generate(32, (i) => i + 3));
      await store.writeKey('a', first);
      await store.writeKey('b', freshKeyBytes(fill: 0x44));

      expect(await store.readKey('a'), first);
      await store.deleteKey('missing');
      expect(await store.readKey('a'), first);

      await store.deleteKey('a');
      expect(await store.readKey('a'), isNull);
      expect(await store.readKey('b'), freshKeyBytes(fill: 0x44));
    });
  });
}
