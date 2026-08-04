import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/journal/sync/saved_moment_sync.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

void main() {
  const cipher = SavedMomentSyncCipher();
  final key = List<int>.generate(32, (index) => index);
  final moment = JournalEntry(
    id: 'entry-1',
    ownerArchiveId: 'account-1',
    createdAt: DateTime.utc(2026, 8),
    transcript: 'exact private words',
    durationSeconds: 1,
    reflection: const Reflection(
      mood: 'steady',
      emotionalIntensity: 1,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );

  test('encrypted envelope round-trips only for its account', () async {
    final record = SavedMomentSyncRecord.fromMoment(
      moment,
      ownerArchiveId: 'account-1',
      revision: 1,
      sourceDeviceId: 'device-1',
    );
    final envelope = await cipher.encrypt(record, keyBytes: key);

    expect(envelope.ciphertextAndMac, isNot(contains(moment.transcript)));
    final decrypted = await cipher.decrypt(
      envelope,
      expectedOwnerArchiveId: 'account-1',
      keyBytes: key,
    );
    expect(decrypted.payload['transcript'], moment.transcript);
    await expectLater(
      cipher.decrypt(
        envelope,
        expectedOwnerArchiveId: 'account-2',
        keyBytes: key,
      ),
      throwsStateError,
    );
  });

  test('tampered ciphertext is rejected', () async {
    final record = SavedMomentSyncRecord.fromMoment(
      moment,
      ownerArchiveId: 'account-1',
      revision: 1,
      sourceDeviceId: 'device-1',
    );
    final envelope = await cipher.encrypt(record, keyBytes: key);
    final tampered = EncryptedSavedMomentEnvelope(
      ownerArchiveId: envelope.ownerArchiveId,
      entryId: envelope.entryId,
      revision: envelope.revision,
      ciphertextAndMac: '${envelope.ciphertextAndMac.substring(0, 8)}AAAA',
      nonce: envelope.nonce,
    );

    await expectLater(
      cipher.decrypt(
        tampered,
        expectedOwnerArchiveId: 'account-1',
        keyBytes: key,
      ),
      throwsA(anything),
    );
  });
}
