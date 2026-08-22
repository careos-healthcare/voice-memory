import 'dart:io';

import 'package:archiveme_mobile/storage/encrypted_json_file_hooks.dart';
import 'package:archiveme_mobile/storage/encrypted_json_file_outcome.dart';
import 'package:archiveme_mobile/storage/encrypted_json_file_store.dart';
import 'package:archiveme_mobile/storage/private_data_encryption_key_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late File target;
  late InMemoryPrivateDataEncryptionKeyStore keyStore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('atomic_enc_json_');
    target = File('${tempDir.path}/journal.enc');
    keyStore = InMemoryPrivateDataEncryptionKeyStore();
    await keyStore.ensureKey();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  EncryptedJsonFileStore store({
    EncryptedJsonFileHooks hooks = EncryptedJsonFileHooks.none,
  }) {
    return EncryptedJsonFileStore(
      file: target,
      keyStore: keyStore,
      hooks: hooks,
    );
  }

  test('write then read returns primary valid payload', () async {
    final s = store();
    expect(
      await s.writeJsonOutcome(['entry-a']),
      isA<EncryptedJsonWriteSuccess>(),
    );
    final outcome = await s.readJsonOutcome();
    expect(outcome, isA<EncryptedJsonReadPrimaryValid>());
    expect((outcome as EncryptedJsonReadPrimaryValid).value, ['entry-a']);
  });

  test('recovers from backup when primary is truncated', () async {
    final s = store();
    await s.writeJson([
      {'id': '1', 'transcript': 'hello'},
    ]);
    await File(
      '${target.path}.bak',
    ).writeAsString(await target.readAsString(), flush: true);
    await target.writeAsString('truncated', flush: true);

    final outcome = await s.readJsonOutcome();
    expect(outcome, isA<EncryptedJsonReadCorruptPrimaryValidBackup>());
  });

  test('authentication failure when primary and backup tampered', () async {
    final s = store();
    await s.writeJson(['x']);
    final primaryRaw = await target.readAsString();
    await target.writeAsString(primaryRaw.replaceFirst('m', 'x'));
    final backup = File('${target.path}.bak');
    if (await backup.exists()) {
      final backupRaw = await backup.readAsString();
      await backup.writeAsString(backupRaw.replaceFirst('m', 'x'));
    }

    final outcome = await s.readJsonOutcome();
    expect(
      outcome,
      anyOf(
        isA<EncryptedJsonReadAuthenticationFailure>(),
        isA<EncryptedJsonReadBothCopiesCorrupt>(),
      ),
    );
  });

  test('failAfterTempWrite preserves previous primary', () async {
    final s = store();
    await s.writeJson(['first']);
    final failing = store(
      hooks: const EncryptedJsonFileHooks(failAfterTempWrite: true),
    );
    expect(
      await failing.writeJsonOutcome(['second']),
      isA<EncryptedJsonWriteDiskFailure>(),
    );
    final outcome = await s.readJsonOutcome();
    expect(outcome, isA<EncryptedJsonReadPrimaryValid>());
    expect((outcome as EncryptedJsonReadPrimaryValid).value, ['first']);
  });

  test(
    'corruptTempFile fails verification without clobbering primary',
    () async {
      final s = store();
      await s.writeJson(['stable']);
      final failing = store(
        hooks: const EncryptedJsonFileHooks(corruptTempFile: true),
      );
      expect(
        await failing.writeJsonOutcome(['lost']),
        isA<EncryptedJsonWriteVerificationFailed>(),
      );
      final read = await s.readJson();
      expect(read, ['stable']);
    },
  );

  test('failBeforeRename leaves primary intact and temp cleaned', () async {
    final s = store();
    await s.writeJson(['before']);
    final failing = store(
      hooks: const EncryptedJsonFileHooks(failBeforeRename: true),
    );
    expect(
      await failing.writeJsonOutcome(['after']),
      isA<EncryptedJsonWriteDiskFailure>(),
    );
    expect(await s.readJson(), ['before']);
    final temps = tempDir.listSync().whereType<File>().where(
      (f) => f.path.contains('.tmp.'),
    );
    expect(temps, isEmpty);
  });

  test('missing file is not treated as corrupt empty archive', () async {
    final s = store();
    expect(await s.readJsonOutcome(), isA<EncryptedJsonReadMissing>());
    expect(await s.readJson(), isNull);
  });

  test('both copies corrupt returns structured outcome', () async {
    final s = store();
    await s.writeJson(['data']);
    await target.writeAsString('bad-primary');
    await File('${target.path}.bak').writeAsString('bad-backup');
    expect(
      await s.readJsonOutcome(),
      isA<EncryptedJsonReadBothCopiesCorrupt>(),
    );
    expect(s.readJson, throwsA(isA<FormatException>()));
  });
}