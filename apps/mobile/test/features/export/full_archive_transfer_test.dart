import 'dart:convert';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:archiveme_mobile/core/crypto/account_sync_key.dart';
import 'package:archiveme_mobile/features/export/full_archive_transfer.dart';
import 'package:archiveme_mobile/features/settings/speech_language_settings.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a passphrase encrypts text the server cannot read', () async {
    AccountSyncKey.debugKdf = Argon2id(
      parallelism: 1,
      memory: 32,
      iterations: 1,
      hashLength: 32,
    );
    addTearDown(() => AccountSyncKey.debugKdf = null);
    const passphrase = 'correct horse';
    final account = AccountSyncKey.generate(Random(3));
    final bundle = await AccountSyncKey.wrap(
      accountKey: account,
      passphrase: passphrase,
      recoveryPhrase: passphrase,
    );
    final opened = await AccountSyncKey.unwrap(
      wrapped: bundle.wrappedByPassphrase,
      secret: passphrase,
    );
    expect(opened, account);
    expect(jsonEncode(bundle.toJson()), isNot(contains('private journal')));
  });

  test('a full archive round-trips journal entries and audio', () async {
    final account = AccountSyncKey.generate(Random(5));
    final bytes = await FullArchiveTransfer.exportZip(
      accountKey: account,
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
      photos: {'bridge.jpg': utf8.encode('photo-bytes')},
    );
    final names = ZipDecoder().decodeBytes(bytes).files.map((file) => file.name);
    expect(
      names,
      containsAll([
        'manifest.json',
        'journal.json',
        'audio/e1.m4a',
        'photos/bridge.jpg',
      ]),
    );
    final imported = await FullArchiveTransfer.importZip(
      accountKey: account,
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
