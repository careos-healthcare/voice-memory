import 'dart:convert';
import 'dart:io';

import 'package:archiveme_crypto/archiveme_crypto.dart';
import 'package:archiveme_crypto/testing.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late File file;
  late InMemoryPrivateDataEncryptionKeyStore keys;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('archiveme_crypto_json_');
    file = File('${tempDir.path}/blob.enc');
    keys = InMemoryPrivateDataEncryptionKeyStore();
    await keys.ensureKey();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  EncryptedJsonFileStore store({
    EncryptedJsonFileHooks hooks = EncryptedJsonFileHooks.none,
    PrivateDataEncryptionKeyStore? keyStore,
  }) {
    return EncryptedJsonFileStore(
      file: file,
      keyStore: keyStore ?? keys,
      hooks: hooks,
    );
  }

  test('write then read is EncryptedJsonReadPrimaryValid', () async {
    final s = store();
    expect(await s.writeJsonOutcome(['alpha']), isA<EncryptedJsonWriteSuccess>());
    final read = await s.readJsonOutcome();
    expect(read, isA<EncryptedJsonReadPrimaryValid>());
    expect((read as EncryptedJsonReadPrimaryValid).value, ['alpha']);
    expect(await s.readJson(), ['alpha']);
    expect(jsonDecodeEnvelopeHasVersion(await file.readAsString()), isTrue);
  });

  test('missing file is EncryptedJsonReadMissing, not an empty archive', () async {
    final s = store();
    expect(await s.readJsonOutcome(), isA<EncryptedJsonReadMissing>());
    expect(await s.readJson(), isNull);
  });

  test('failAfterTempWrite leaves the previous primary intact', () async {
    final s = store();
    await s.writeJson(['stable']);
    final before = await file.readAsString();
    final failing = store(hooks: const EncryptedJsonFileHooks(failAfterTempWrite: true));
    expect(
      await failing.writeJsonOutcome(['must-not-land']),
      isA<EncryptedJsonWriteDiskFailure>(),
    );
    expect(await file.readAsString(), before);
    expect(await s.readJson(), ['stable']);
    expect(tempDir.listSync().whereType<File>().where((f) => f.path.contains('.tmp.')), isEmpty);
  });

  test('corruptTempFile fails verification without clobbering primary', () async {
    final s = store();
    await s.writeJson(['stable']);
    final failing = store(hooks: const EncryptedJsonFileHooks(corruptTempFile: true));
    expect(
      await failing.writeJsonOutcome(['lost']),
      isA<EncryptedJsonWriteVerificationFailed>(),
    );
    expect(await s.readJson(), ['stable']);
  });

  test('failBeforeRename leaves primary intact and cleans temp', () async {
    final s = store();
    await s.writeJson(['before']);
    final failing = store(hooks: const EncryptedJsonFileHooks(failBeforeRename: true));
    expect(
      await failing.writeJsonOutcome(['after']),
      isA<EncryptedJsonWriteDiskFailure>(),
    );
    expect(await s.readJson(), ['before']);
    expect(tempDir.listSync().whereType<File>().where((f) => f.path.contains('.tmp.')), isEmpty);
  });

  test('failAfterEncrypt never writes a temp or primary', () async {
    expect(
      await store(hooks: const EncryptedJsonFileHooks(failAfterEncrypt: true)).writeJsonOutcome(['x']),
      isA<EncryptedJsonWriteDiskFailure>(),
    );
    expect(file.existsSync(), isFalse);
  });

  test('truncated primary with a valid .bak is EncryptedJsonReadCorruptPrimaryValidBackup', () async {
    final s = store();
    await s.writeJson({'id': 'one'});
    await File('${file.path}.bak').writeAsString(await file.readAsString());
    await file.writeAsString('truncated', flush: true);
    final outcome = await s.readJsonOutcome();
    expect(outcome, isA<EncryptedJsonReadCorruptPrimaryValidBackup>());
    expect((outcome as EncryptedJsonReadCorruptPrimaryValidBackup).value, {'id': 'one'});
  });

  test('missing primary with a valid .bak is EncryptedJsonReadRecoveredFromBackup', () async {
    final s = store();
    await s.writeJson(['from-bak']);
    await File('${file.path}.bak').writeAsString(await file.readAsString());
    await file.delete();
    final outcome = await s.readJsonOutcome();
    expect(outcome, isA<EncryptedJsonReadRecoveredFromBackup>());
    expect((outcome as EncryptedJsonReadRecoveredFromBackup).value, ['from-bak']);
  });

  test('both copies garbage is EncryptedJsonReadBothCopiesCorrupt', () async {
    final s = store();
    await s.writeJson(['data']);
    await file.writeAsString('bad-primary');
    await File('${file.path}.bak').writeAsString('bad-backup');
    expect(await s.readJsonOutcome(), isA<EncryptedJsonReadBothCopiesCorrupt>());
    expect(s.readJson, throwsA(isA<FormatException>()));
  });

  test('tampered mac is EncryptedJsonReadAuthenticationFailure', () async {
    final s = store();
    await s.writeJson(['x']);
    final envelope = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final macBytes = base64Decode(envelope['m'] as String);
    macBytes[0] ^= 0xff;
    envelope['m'] = base64Encode(macBytes);
    await file.writeAsString(jsonEncode(envelope));
    final outcome = await s.readJsonOutcome();
    expect(outcome, isA<EncryptedJsonReadAuthenticationFailure>());
    expect(
      (outcome as EncryptedJsonReadAuthenticationFailure).recoveredFromBackup,
      isFalse,
    );
  });

  test('a host key store that never persists is EncryptedJsonReadKeyUnavailable', () async {
    await file.writeAsString('{"v":1,"n":"YQ==","c":"YQ==","m":"YQ=="}');
    final s = EncryptedJsonFileStore(file: file, keyStore: _RefusingKeyStore());
    expect(await s.readJsonOutcome(), isA<EncryptedJsonReadKeyUnavailable>());
    expect(
      await s.writeJsonOutcome(['nope']),
      isA<EncryptedJsonWriteKeyUnavailable>(),
    );
  });

  test('ensureKey via SecurePrivateDataEncryptionKeyStore then round-trips', () async {
    final backend = MemoryKeyMaterialStore();
    final keyStore = SecurePrivateDataEncryptionKeyStore(store: backend);
    final s = EncryptedJsonFileStore(file: file, keyStore: keyStore);
    await s.writeJson(['via-secure']);
    expect(await s.readJson(), ['via-secure']);
  });

  test('failAfterVerify does not rename over the primary', () async {
    final s = store();
    await s.writeJson(['keep']);
    final before = await file.readAsString();
    expect(
      await store(hooks: const EncryptedJsonFileHooks(failAfterVerify: true)).writeJsonOutcome(['drop']),
      isA<EncryptedJsonWriteDiskFailure>(),
    );
    expect(await file.readAsString(), before);
  });

  test('migrateFromPlaintextFile encrypts and can remove the plaintext', () async {
    final plaintext = File('${tempDir.path}/legacy.json');
    await plaintext.writeAsString('[{"id":"legacy"}]');
    final result = await store().migrateFromPlaintextFile(plaintext);
    expect(result.migrated, isTrue);
    expect(result.plaintextRemoved, isTrue);
    expect(plaintext.existsSync(), isFalse);
    expect(await store().readJson(), [
      {'id': 'legacy'},
    ]);
    expect(
      await EncryptedJsonFileStore.fileOmitsPlaintextNeedle(file, 'legacy'),
      isTrue,
    );
  });

  test('skipBackup does not create a .bak on a successful rewrite', () async {
    final s = store();
    await s.writeJson(['first']);
    expect(
      await store(hooks: const EncryptedJsonFileHooks(skipBackup: true)).writeJsonOutcome(['second']),
      isA<EncryptedJsonWriteSuccess>(),
    );
    expect(File('${file.path}.bak').existsSync(), isFalse);
    expect(await s.readJson(), ['second']);
  });

  test('empty plaintext migrates to an empty list', () async {
    final plaintext = File('${tempDir.path}/empty.json');
    await plaintext.writeAsString('   ');
    final result = await store().migrateFromPlaintextFile(plaintext);
    expect(result.migrated, isTrue);
    expect(await store().readJson(), []);
  });

  test('migrateFromPlaintextFile is a no-op when the encrypted file already exists', () async {
    await store().writeJson(['already']);
    final plaintext = File('${tempDir.path}/legacy.json');
    await plaintext.writeAsString('[{"id":"ignored"}]');
    final result = await store().migrateFromPlaintextFile(plaintext);
    expect(result.migrated, isFalse);
    expect(await store().readJson(), ['already']);
  });

  test('writeJson maps key-unavailable to StateError', () async {
    final s = EncryptedJsonFileStore(file: file, keyStore: _RefusingKeyStore());
    expect(() => s.writeJson(['nope']), throwsA(isA<StateError>()));
  });

  test('writeJson maps disk failure to FileSystemException', () async {
    expect(
      () => store(
        hooks: const EncryptedJsonFileHooks(failAfterEncrypt: true),
      ).writeJson(['x']),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('writeJson maps verification failure to StateError', () async {
    await store().writeJson(['stable']);
    expect(
      () => store(
        hooks: const EncryptedJsonFileHooks(corruptTempFile: true),
      ).writeJson(['lost']),
      throwsA(isA<StateError>()),
    );
  });

  test('overlapping writeJson calls leave one consistent decrypted payload', () async {
    final s = store();
    await Future.wait([
      s.writeJson(['first']),
      s.writeJson(['second']),
    ]);
    expect(await s.readJson(), anyOf(equals(['first']), equals(['second'])));
    expect(jsonDecodeEnvelopeHasVersion(await file.readAsString()), isTrue);
    expect(
      tempDir.listSync().whereType<File>().where((f) => f.path.contains('.tmp.')),
      isEmpty,
    );
  });
}

bool jsonDecodeEnvelopeHasVersion(String raw) => raw.contains('"v":1') || raw.contains('"v": 1');

class _RefusingKeyStore implements PrivateDataEncryptionKeyStore {
  @override
  Future<List<int>?> readKeyBytes() async => null;

  @override
  Future<void> writeKeyBytes(List<int> keyBytes) async {}

  @override
  Future<void> deleteKey() async {}
}
