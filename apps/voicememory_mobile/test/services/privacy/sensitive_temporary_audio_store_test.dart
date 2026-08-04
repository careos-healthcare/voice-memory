import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:voicememory_mobile/services/privacy/sensitive_temporary_audio_store.dart';

void main() {
  late Directory sandbox;
  late Directory protected;
  late Directory legacy;
  late DateTime now;

  SensitiveTemporaryAudioStore build({
    int maxItems = 20,
    int maxBytes = 512 * 1024 * 1024,
  }) {
    return SensitiveTemporaryAudioStore(
      directory: () async => protected,
      legacyDirectories: [() async => legacy],
      clock: () => now,
      random: Random(7),
      maxItems: maxItems,
      maxBytes: maxBytes,
    );
  }

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('sensitive_audio_store_');
    protected = Directory(p.join(sandbox.path, 'protected'));
    legacy = Directory(p.join(sandbox.path, 'legacy'))..createSync();
    now = DateTime.utc(2026, 8, 1, 10);
  });

  tearDown(() {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  test(
    'uses opaque names and preserves creation across state changes',
    () async {
      final store = build();
      final file = await store.create(ownerId: 'capture-a', extension: '.wav');
      await file.writeAsBytes([1, 2, 3]);
      final name = p.basename(file.path);

      expect(name, matches(RegExp(r'^[0-9a-f]{48}\.wav$')));
      expect(name, isNot(contains('vm_rec')));
      expect(name, isNot(contains('2026')));

      final created = (await store.list(ownerId: 'capture-a')).single.createdAt;
      now = now.add(const Duration(hours: 4));
      await store.markRecoverable(file: file, ownerId: 'capture-a');
      expect(
        (await store.list(ownerId: 'capture-a')).single.createdAt,
        created,
      );
    },
  );

  test('enforces fixed 24 hour TTL from original creation', () async {
    final store = build();
    final file = await store.create(ownerId: 'capture-a', extension: 'm4a');
    await file.writeAsBytes([1]);
    await store.markRecoverable(file: file, ownerId: 'capture-a');

    now = now.add(const Duration(hours: 23, minutes: 59));
    expect(await store.list(ownerId: 'capture-a'), hasLength(1));
    now = now.add(const Duration(minutes: 1));
    expect(await store.list(ownerId: 'capture-a'), isEmpty);
    expect(file.existsSync(), isFalse);
  });

  test('bounds item count and bytes by purging oldest items', () async {
    final store = build(maxItems: 2, maxBytes: 5);
    final first = await store.create(ownerId: 'capture-a', extension: 'wav');
    await first.writeAsBytes([1, 1, 1]);
    await store.markRecoverable(file: first, ownerId: 'capture-a');
    now = now.add(const Duration(minutes: 1));
    final second = await store.create(ownerId: 'capture-a', extension: 'wav');
    await second.writeAsBytes([2, 2, 2]);
    await store.markRecoverable(file: second, ownerId: 'capture-a');

    expect(first.existsSync(), isFalse);
    expect(second.existsSync(), isTrue);
    expect(await store.list(ownerId: 'capture-a'), hasLength(1));
  });

  test('owner isolation applies to list, open, state, and delete', () async {
    final store = build();
    final file = await store.create(ownerId: 'owner-a', extension: 'wav');
    await file.writeAsBytes([4, 5, 6]);

    expect(await store.list(ownerId: 'owner-b'), isEmpty);
    await expectLater(
      store.controlledOpen<int>(
        file: file,
        ownerId: 'owner-b',
        operation: (handle) => handle.length(),
      ),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      store.delete(file: file, ownerId: 'owner-b'),
      throwsA(isA<FileSystemException>()),
    );
    expect(file.existsSync(), isTrue);
  });

  test(
    'encryption completion immediately removes source and metadata',
    () async {
      final store = build();
      final file = await store.create(ownerId: 'capture-a', extension: 'wav');
      await file.writeAsBytes([9, 8, 7]);

      await store.markEncryptionComplete(file: file, ownerId: 'capture-a');

      expect(file.existsSync(), isFalse);
      expect(File('${file.path}.meta').existsSync(), isFalse);
    },
  );

  test('moves legacy files once without leaving plaintext copies', () async {
    final valid = File(p.join(legacy.path, 'vm_rec_person_words.wav'));
    await valid.writeAsBytes([1, 2, 3, 4]);
    await valid.setLastModified(now.subtract(const Duration(hours: 2)));
    final expired = File(p.join(legacy.path, 'vm_rec_expired.m4a'));
    await expired.writeAsBytes([1]);
    await expired.setLastModified(now.subtract(const Duration(hours: 25)));
    final corrupt = File(p.join(legacy.path, 'vm_rec_empty.wav'))..createSync();
    final store = build();

    await store.migrateLegacyOnce();

    expect(valid.existsSync(), isFalse);
    expect(expired.existsSync(), isFalse);
    expect(corrupt.existsSync(), isFalse);
    final recovered = await store.list(ownerId: 'legacy-recovery');
    expect(recovered, hasLength(1));
    expect(recovered.single.createdAt, now.subtract(const Duration(hours: 2)));
    expect(p.basename(recovered.single.file.path), isNot(contains('person')));

    File(p.join(legacy.path, 'vm_rec_later.wav')).writeAsBytesSync([1, 2, 3]);
    await store.migrateLegacyOnce();
    expect(File(p.join(legacy.path, 'vm_rec_later.wav')).existsSync(), isTrue);
  });

  test('migration preserves timestamped legacy creation time', () async {
    final original = DateTime.utc(2026, 7, 31, 14, 30);
    final legacyFile = File(
      p.join(legacy.path, 'vm_rec_${original.millisecondsSinceEpoch}.wav'),
    );
    await legacyFile.writeAsBytes([1, 2, 3]);
    await legacyFile.setLastModified(now);
    final store = build();

    await store.migrateLegacyOnce();

    final recovered = await store.list(ownerId: 'legacy-recovery');
    expect(recovered.single.createdAt, original);
  });
}
