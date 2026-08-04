import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/codex_press/codex_encryption_manager.dart';
import 'package:voicememory_mobile/features/codex_press/codex_models.dart';
import 'package:voicememory_mobile/services/security/sync_identity_service.dart';

import 'codex_renderers_test.dart';

void main() {
  late CodexEncryptionManager manager;

  setUp(() {
    manager = CodexEncryptionManager(
      random: Random(42),
      passwordIterations: 1000,
      recoveryKeyProvider: () async =>
          SyncEncryptionKey(List<int>.generate(32, (index) => index)),
    );
  });

  test(
    'password and Sanctuary slots unwrap the same encrypted payload',
    () async {
      final encoded = await manager.encrypt(
        manuscript: sampleCodexManuscript(),
        artifacts: CodexRenderedArtifacts(
          pdf: ascii.encode('%PDF-test'),
          epub: [1, 2, 3],
          offlineHtml: utf8.encode('<!doctype html>'),
        ),
        password: 'correct horse battery staple',
        includeRecoverySlot: true,
      );

      final password = await manager.decryptWithPassword(
        encoded,
        'correct horse battery staple',
      );
      final recovery = await manager.decryptWithRecovery(encoded);
      expect(password.keys, containsAll(recovery.keys));
      expect(
        utf8.decode(password['manuscript.json']!),
        utf8.decode(recovery['manuscript.json']!),
      );
      expect(utf8.decode(encoded), isNot(contains('correct horse')));
    },
  );

  test('wrong credentials and tampering use a uniform failure', () async {
    final encoded = await manager.encrypt(
      manuscript: sampleCodexManuscript(),
      artifacts: CodexRenderedArtifacts(pdf: [1], epub: [2], offlineHtml: [3]),
      password: 'correct horse battery staple',
    );

    expect(
      () => manager.decryptWithPassword(encoded, 'wrong password entirely'),
      throwsA(isA<CodexAuthenticationException>()),
    );

    final json = jsonDecode(utf8.decode(encoded)) as Map<String, dynamic>;
    final ciphertext = base64Decode(json['payloadCiphertext'] as String);
    ciphertext[0] ^= 1;
    json['payloadCiphertext'] = base64Encode(ciphertext);
    final tampered = Uint8List.fromList(utf8.encode(jsonEncode(json)));
    expect(
      () =>
          manager.decryptWithPassword(tampered, 'correct horse battery staple'),
      throwsA(isA<CodexAuthenticationException>()),
    );
  });
}
