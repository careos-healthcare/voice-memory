import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/codex_press/codex_encryption_manager.dart';
import 'package:voicememory_mobile/features/codex_press/codex_models.dart';
import 'package:voicememory_mobile/features/export_backup/vault_backup_models.dart';
import 'package:voicememory_mobile/features/export_backup/vault_format.dart';
import 'package:voicememory_mobile/features/sanctuary_core/sanctuary_keyring_manager.dart';
import 'package:voicememory_mobile/services/security/sanctuary_key_audit.dart';
import 'package:voicememory_mobile/services/security/sync_identity_service.dart';

void main() {
  test('key audit rejects a non-zero destruction callback', () {
    expect(
      () => SanctuaryKeyAudit().observeDestroyedKey(
        'payload-dek',
        Uint8List.fromList([0, 1, 0]),
      ),
      throwsA(isA<SanctuaryKeyAuditViolation>()),
    );
  });

  test('Codex destroys every observed DEK and KEK after use', () async {
    final audit = SanctuaryKeyAudit();
    final manager = CodexEncryptionManager(
      random: Random(7),
      passwordIterations: 1000,
      recoveryKeyProvider: () async =>
          SyncEncryptionKey(List<int>.generate(32, (index) => index + 1)),
      destroyedKeyObserver: audit.observeDestroyedKey,
    );
    final encrypted = await manager.encrypt(
      manuscript: _manuscript(),
      artifacts: CodexRenderedArtifacts(
        pdf: [1, 2],
        epub: [3, 4],
        offlineHtml: [5, 6],
      ),
      password: 'audit password is long enough',
      includeRecoverySlot: true,
    );
    await manager.decryptWithPassword(
      encrypted,
      'audit password is long enough',
    );
    await manager.decryptWithRecovery(encrypted);

    audit
      ..requireDestruction('payload-dek', minimumCount: 3)
      ..requireDestruction('password-kek', minimumCount: 2)
      ..requireDestruction('recovery-kek', minimumCount: 2);
  });

  test('password slots use fresh salts and authenticate integrity', () async {
    final manager = CodexEncryptionManager(
      random: Random(19),
      passwordIterations: 1000,
      recoveryKeyProvider: () async => null,
    );
    Future<Uint8List> encrypt() => manager.encrypt(
      manuscript: _manuscript(),
      artifacts: CodexRenderedArtifacts(pdf: [1], epub: [2], offlineHtml: [3]),
      password: 'another sufficiently long password',
    );

    final first = await encrypt();
    final second = await encrypt();
    final firstJson = jsonDecode(utf8.decode(first)) as Map<String, dynamic>;
    final secondJson = jsonDecode(utf8.decode(second)) as Map<String, dynamic>;
    final firstSlot =
        (firstJson['slots'] as List).single as Map<String, dynamic>;
    final secondSlot =
        (secondJson['slots'] as List).single as Map<String, dynamic>;

    expect(firstSlot['salt'], isNot(secondSlot['salt']));
    expect(firstJson['manifestSha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(
      utf8.decode(first),
      isNot(contains('another sufficiently long password')),
    );
  });

  test(
    'Sanctuary portable recovery material is never plaintext on disk',
    () async {
      const phrase =
          'abandon ability able about above absent absorb abstract absurd abuse access accident';
      final portableKey = Uint8List.fromList(List<int>.filled(32, 0x5a));
      final provider = _PortableProvider(phrase, portableKey);
      final cryptography = VaultCryptography(random: Random(31));
      final manager = SanctuaryKeyringManager(
        identity: SyncIdentityService(store: MemorySyncIdentityStore()),
        portableKeys: provider,
        authenticateOwner: (_) async => true,
        rotateSyncKey: () async => phrase,
        cryptography: cryptography,
        clock: () => DateTime.utc(2026),
      );
      final directory = await Directory.systemTemp.createTemp('key-audit-');
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      final file = await manager.exportEncryptedKeyBackup(
        directory: directory,
        password: 'sanctuary audit password',
      );

      expect(file, isNotNull);
      final diskBytes = await file!.readAsBytes();
      final diskText = utf8.decode(diskBytes);
      expect(diskText, isNot(contains(phrase)));
      expect(diskText, isNot(contains(base64Encode(portableKey))));
      expect(await File('${file.path}.tmp').exists(), isFalse);
      await SanctuaryKeyAudit().assertNoPlaintextSecrets(
        directory: directory,
        textSecrets: const [phrase],
        binarySecrets: [portableKey],
      );

      final clear = await cryptography.decrypt(
        VaultEnvelope.fromBytes(Uint8List.fromList(diskBytes)),
        VaultCredential.password('sanctuary audit password'),
      );
      final restored = VaultPortableKeyring.fromBytes(clear);
      expect(restored.syncPhrase, phrase);
      expect(
        restored.keys[VaultPortableKey.privateDataEncryption],
        portableKey,
      );
      restored.wipe();
      clear.fillRange(0, clear.length, 0);
    },
  );

  test('key audit detects plaintext fallback material on disk', () async {
    final directory = await Directory.systemTemp.createTemp(
      'key-audit-negative-',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    await File(
      '${directory.path}/unsafe.key',
    ).writeAsString('local fallback phrase');

    await expectLater(
      SanctuaryKeyAudit().assertNoPlaintextSecrets(
        directory: directory,
        textSecrets: const ['local fallback phrase'],
      ),
      throwsA(isA<SanctuaryKeyAuditViolation>()),
    );
  });
}

CodexManuscript _manuscript() => CodexManuscript(
  id: 'security-audit-codex',
  title: 'Security Audit',
  template: CodexPublicationTemplate.academicMonograph,
  organization: CodexOrganization.chronological,
  generatedAt: DateTime.utc(2026),
  chapters: [
    CodexChapter(
      id: 'chapter',
      title: 'Evidence',
      ordinal: 0,
      start: DateTime.utc(2025),
      end: DateTime.utc(2025),
      passages: [
        CodexPassage(
          heading: 'Local source',
          text: 'Source-bound content.',
          citations: [
            CodexCitation(
              sourceId: 'journal-1',
              kind: CodexSourceKind.journal,
              occurredAt: DateTime.utc(2025),
              label: 'Journal',
            ),
          ],
        ),
      ],
    ),
  ],
);

final class _PortableProvider implements VaultPortableKeyProvider {
  const _PortableProvider(this.phrase, this.key);

  final String phrase;
  final Uint8List key;

  @override
  Future<VaultPortableKeyring> exportPortableKeys({
    required bool includeSyncPhrase,
  }) async => VaultPortableKeyring(
    keys: {VaultPortableKey.privateDataEncryption: key},
    syncPhrase: includeSyncPhrase ? phrase : null,
  );
}
