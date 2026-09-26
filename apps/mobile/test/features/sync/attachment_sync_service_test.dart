import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/core/crypto/passphrase_vault.dart';
import 'package:archiveme_mobile/features/sync/services/attachment_sync_service.dart';
import 'package:archiveme_mobile/features/sync/services/entry_encryption_service.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'audio and photos upload as ciphertext and download only when missing',
    () async {
      final vault = await PassphraseVault.open(
        passphrase: 'thoughtprint-sync-passphrase',
        store: SaltStore(),
      );
      final encryption = EntryEncryptionService(vault);
      final dir = await Directory.systemTemp.createTemp(
        'thoughtprint-attachments',
      );
      addTearDown(() => dir.delete(recursive: true));

      const marker = 'PLAINTEXT-AUDIO-MARKER-river';
      final audio = File('${dir.path}/river.m4a');
      await audio.writeAsBytes(utf8.encode(marker));
      final photo = File('${dir.path}/river.jpg');
      await photo.writeAsBytes(utf8.encode('photo-bytes'));

      final uploaded = <String, List<int>>{};
      final service = AttachmentSyncService(
        encryption: encryption,
        sign:
            ({
              required String entryId,
              required String name,
              required String method,
            }) async {
              return SignedObjectGrant(
                url: Uri.parse(
                  'https://storage.example/$entryId/$name?method=$method',
                ),
              );
            },
        putBytes: (grant, body) async {
          uploaded[grant.url.path] = body;
        },
        getBytes: (grant) async => uploaded[grant.url.path]!,
      );

      final entry = JournalEntry(
        id: 'entry-river-2026',
        createdAt: DateTime.utc(2026, 3, 8),
        transcript: 'the river was high',
        durationSeconds: 4,
        localAudioPath: audio.path,
        imageEvidence: ImageEvidence(
          evidenceId: 'photo-1',
          caption: '',
          mimeType: 'image/jpeg',
          attachedAt: DateTime.utc(2026, 3, 8),
          images: [photo.path],
        ),
        reflection: const Reflection(
          mood: 'quiet',
          emotionalIntensity: 1,
          recurringThemes: [],
          exactLanguagePattern: '',
          concreteObservation: '',
          repeatedSignal: '',
        ),
      );

      await service.uploadEntryAttachments(entry);

      expect(uploaded, hasLength(2));
      for (final body in uploaded.values) {
        final text = utf8.decode(body);
        expect(text.contains(marker), isFalse);
        expect(text.contains('nonce'), isTrue);
      }

      expect(
        await service.ensureLocalFile(entryId: entry.id, path: audio.path),
        isFalse,
      );

      await audio.delete();
      expect(
        await service.ensureLocalFile(entryId: entry.id, path: audio.path),
        isTrue,
      );
      expect(utf8.decode(await audio.readAsBytes()), marker);
    },
  );
}
