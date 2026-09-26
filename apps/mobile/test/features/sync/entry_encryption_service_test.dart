import 'package:archiveme_mobile/core/crypto/passphrase_vault.dart';
import 'package:archiveme_mobile/features/sync/services/entry_encryption_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each entry seals and opens on its own', () async {
    const passphrase = 'thoughtprint-sync-passphrase';
    final vault = await PassphraseVault.open(
      passphrase: passphrase,
      store: SaltStore(),
    );
    final service = EntryEncryptionService(vault);
    final entry = JournalEntry(
      id: 'entry-river-2026',
      createdAt: DateTime.utc(2026, 3, 8, 15),
      transcript: 'the river was high after the rain',
      durationSeconds: 4,
      reflection: const Reflection(
        mood: 'quiet',
        emotionalIntensity: 1,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );

    final sealed = await service.encryptSingleEntry(entry);

    expect(sealed.id, entry.id);
    expect(sealed.version, EntryEncryptionService.version);
    expect(sealed.nonce, isNotEmpty);
    expect(sealed.ciphertext.contains('the river was high'), isFalse);
    expect(
      sealed.toJson().keys,
      containsAll(['id', 'version', 'nonce', 'ciphertext']),
    );

    final opened = await service.decryptSingleEntry(sealed);
    expect(opened.transcript, entry.transcript);
    expect(opened.id, entry.id);
  });
}
