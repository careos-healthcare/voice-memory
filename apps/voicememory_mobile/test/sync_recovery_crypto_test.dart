import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/sync_recovery/sync_recovery_crypto.dart';

void main() {
  const crypto = SyncRecoveryCrypto();
  final key = List<int>.generate(32, (index) => index);

  test('wraps and unwraps a random sync key', () async {
    final setup = await crypto.wrap(
      syncKey: key,
      ownerAccountId: 'account-a',
      ownerArchiveId: 'archive-a',
      keyEpoch: 1,
      envelopeRevision: 1,
    );
    expect(setup.secret, isNot(contains('account-a')));
    expect(setup.envelope.ciphertext, isNot(contains('AAECAw')));
    expect(
      await crypto.unwrap(
        envelope: setup.envelope,
        secret: setup.secret,
        expectedAccountId: 'account-a',
        expectedArchiveId: 'archive-a',
        expectedKeyEpoch: 1,
      ),
      key,
    );
  });

  test('one-character error and truncated secrets fail closed', () async {
    final setup = await crypto.wrap(
      syncKey: key,
      ownerAccountId: 'account-a',
      ownerArchiveId: 'archive-a',
      keyEpoch: 1,
      envelopeRevision: 1,
    );
    final firstCharacter = setup.secret[0];
    final oneCharacterError =
        '${firstCharacter == 'A' ? 'B' : 'A'}${setup.secret.substring(1)}';
    for (final secret in [
      oneCharacterError,
      setup.secret.substring(0, setup.secret.length - 5),
    ]) {
      expect(
        () => crypto.unwrap(
          envelope: setup.envelope,
          secret: secret,
          expectedAccountId: 'account-a',
          expectedArchiveId: 'archive-a',
        ),
        throwsA(isA<SyncRecoveryException>()),
      );
    }
  });

  test('tamper, owner, archive, schema, epoch, and replay fail closed', () async {
    final setup = await crypto.wrap(
      syncKey: key,
      ownerAccountId: 'account-a',
      ownerArchiveId: 'archive-a',
      keyEpoch: 1,
      envelopeRevision: 2,
    );
    final json = setup.envelope.toJson();

    Future<void> rejects(
      Map<String, dynamic> candidate, {
      String account = 'account-a',
      String archive = 'archive-a',
      int? epoch,
      int? minimumRevision,
    }) async {
      await expectLater(
        crypto.unwrap(
          envelope: SyncRecoveryEnvelope.fromJson(candidate),
          secret: setup.secret,
          expectedAccountId: account,
          expectedArchiveId: archive,
          expectedKeyEpoch: epoch,
          minimumEnvelopeRevision: minimumRevision,
        ),
        throwsA(isA<SyncRecoveryException>()),
      );
    }

    final ciphertext = json['ciphertext'] as String;
    await rejects({
      ...json,
      'ciphertext':
          '${ciphertext.startsWith('A') ? 'B' : 'A'}${ciphertext.substring(1)}',
    });
    await rejects(json, account: 'account-b');
    await rejects(json, archive: 'archive-b');
    await rejects({...json, 'schemaVersion': 2});
    await rejects(json, epoch: 2);
    await rejects(json, minimumRevision: 3);
  });

  test('metadata changes are authenticated', () async {
    final setup = await crypto.wrap(
      syncKey: key,
      ownerAccountId: 'account-a',
      ownerArchiveId: 'archive-a',
      keyEpoch: 1,
      envelopeRevision: 1,
    );
    final tampered = SyncRecoveryEnvelope.fromJson({
      ...setup.envelope.toJson(),
      'updatedAt': setup.envelope.updatedAt
          .add(const Duration(seconds: 1))
          .toIso8601String(),
    });
    await expectLater(
      crypto.unwrap(
        envelope: tampered,
        secret: setup.secret,
        expectedAccountId: 'account-a',
        expectedArchiveId: 'archive-a',
      ),
      throwsA(isA<SyncRecoveryException>()),
    );
  });
}
