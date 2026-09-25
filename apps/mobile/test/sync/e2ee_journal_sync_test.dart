import 'package:archiveme_mobile/core/crypto/e2e_encryption_service.dart';
import 'package:archiveme_mobile/core/crypto/passphrase_vault.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/sync/e2ee_journal_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const passphrase = 'thoughtprint-sync-passphrase';

  JournalEntry entry({
    required String id,
    required DateTime updatedAt,
    required String transcript,
  }) {
    return JournalEntry(
      id: id,
      createdAt: DateTime.utc(2026, 3, 8),
      transcript: transcript,
      durationSeconds: 4,
      reflection: const Reflection(
        mood: 'quiet',
        emotionalIntensity: 1,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      updatedAt: updatedAt,
    );
  }

  test('last write wins keeps the newer updated_at', () {
    final older = entry(
      id: 'river',
      updatedAt: DateTime.utc(2026, 3, 8, 12),
      transcript: 'the river was high',
    );
    final newer = entry(
      id: 'river',
      updatedAt: DateTime.utc(2026, 3, 9, 12),
      transcript: 'the river fell overnight',
    );

    expect(E2eeJournalSync.lastWriteWins(older, newer).transcript, newer.transcript);
    expect(E2eeJournalSync.lastWriteWins(newer, older).transcript, newer.transcript);

    final merged = E2eeJournalSync.mergeByUpdatedAt(
      local: [older],
      remote: [
        newer,
        entry(
          id: 'market',
          updatedAt: DateTime.utc(2026, 3, 8, 18),
          transcript: 'the market was loud',
        ),
      ],
    );
    expect(merged.map((row) => row.id), containsAll(['river', 'market']));
    expect(merged.firstWhere((row) => row.id == 'river').transcript, newer.transcript);
  });

  test('serialized sqlite rows are encrypted before a cloud push', () async {
    final rows = [
      entry(
        id: 'entry-river-2026',
        updatedAt: DateTime.utc(2026, 3, 8, 15, 4),
        transcript: 'the river was high after the rain',
      ),
    ];
    final memory = SaltStore();
    final blob = await E2eeJournalSync.encryptSnapshot(
      encryption: E2EEncryptionService(),
      openVault: (value) => PassphraseVault.open(passphrase: value, store: memory),
      entries: rows,
      passphrase: passphrase,
    );

    expect(blob.encrypted.ciphertext.contains('the river was high'), isFalse);
    expect(blob.toJson().containsKey('transcript'), isFalse);
    expect(await memory.read('e2ee_salt'), isNotNull);

    final restored = await E2eeJournalSync.decryptSnapshot(
      encryption: E2EEncryptionService(),
      envelope: blob.encrypted,
      passphrase: passphrase,
    );
    expect(restored.single.transcript, rows.single.transcript);
    expect(restored.single.updatedAt, rows.single.updatedAt);

    final older = entry(
      id: 'entry-river-2026',
      updatedAt: DateTime.utc(2026, 3, 7, 9),
      transcript: 'the river was low',
    );
    final merged = await E2eeJournalSync.applyRemoteSnapshot(
      encryption: E2EEncryptionService(),
      envelope: blob.encrypted,
      passphrase: passphrase,
      local: [older],
    );
    expect(merged.single.transcript, rows.single.transcript);
    expect(merged.single.updatedAt, rows.single.updatedAt);
  });
}
