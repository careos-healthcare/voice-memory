import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:archiveme_mobile/core/crypto/passphrase_vault.dart';
import 'package:archiveme_mobile/features/export/full_archive_transfer.dart';
import 'package:archiveme_mobile/features/settings/speech_language_settings.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a passphrase encrypts text the server cannot read', () async {
    final store = SaltStore();
    final vault = await PassphraseVault.open(
      passphrase: 'correct horse',
      store: store,
    );
    final blob = await vault.encrypt(utf8.encode('private journal'));
    expect(blob.ciphertext, isNot(contains('private journal')));
    final clear = await vault.decrypt(blob);
    expect(utf8.decode(clear), 'private journal');
    final again = await PassphraseVault.open(
      passphrase: 'correct horse',
      store: store,
    );
    expect(utf8.decode(await again.decrypt(blob)), 'private journal');
  });

  test('a full archive round-trips journal entries and audio', () async {
    final vault = await PassphraseVault.open(
      passphrase: 'archive',
      store: SaltStore(),
    );
    final bytes = await FullArchiveTransfer.exportZip(
      vault: vault,
      entries: [
        ArchiveTransferEntry(
          id: 'e1',
          createdAt: DateTime.utc(2026, 3, 8),
          transcript: 'the river',
          tags: const ['walk'],
          mood: 'quiet',
          place: 'bridge',
          audioFileName: 'e1.m4a',
        ),
      ],
      audio: {'e1.m4a': utf8.encode('audio-bytes')},
    );
    final names = ZipDecoder().decodeBytes(bytes).files.map((file) => file.name);
    expect(names, containsAll(['manifest.json', 'journal.json', 'audio/e1.m4a']));
    final imported = await FullArchiveTransfer.importZip(
      vault: vault,
      bytes: bytes,
    );
    expect(imported.schemaVersion, 1);
    expect(imported.entries.single.transcript, 'the river');
    expect(imported.entries.single.place, 'bridge');
    final merged = FullArchiveTransfer.merge(const [], imported.entries);
    expect(merged.single.id, 'e1');
  });

  test('Hindi and Japanese become the codes Whisper expects', () {
    expect(
      TranscriptionLanguage.whisperCode(
        ConfirmedSpeechLocale.confirmed('hi-IN')!,
      ),
      'hi',
    );
    expect(
      TranscriptionLanguage.whisperCode(
        ConfirmedSpeechLocale.confirmed('ja-JP')!,
      ),
      'ja',
    );
  });
}
