import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/features/export/services/qr_audio_service.dart';
import 'package:archiveme_mobile/models/journal_display_metadata.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({required String id, String? audio}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 3, 8),
    transcript: 'the river was high',
    durationSeconds: 8,
    localAudioPath: audio,
    reflection: const Reflection(
      mood: 'calm',
      emotionalIntensity: 1,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    display: const JournalDisplayMetadata(),
  );
}

void main() {
  test(
    'a recording is sealed before upload and the key stays in the link',
    () async {
      final dir = await Directory.systemTemp.createTemp('audio_qr_');
      final file = File('${dir.path}/moment.m4a');
      final plain = [1, 2, 3, 4, 5, 9, 8, 7];
      await file.writeAsBytes(plain);
      List<int>? uploaded;
      String? uploadedNonce;
      String? uploadedMac;
      final service = QrAudioService(
        upload:
            ({
              required String entryId,
              required List<int> ciphertext,
              required String nonce,
              required String mac,
            }) async {
              expect(entryId, 'river');
              expect(ciphertext, isNot(plain));
              uploaded = ciphertext;
              uploadedNonce = nonce;
              uploadedMac = mac;
              return QrAudioLink(
                url: 'https://example.com/api/export/audio-qr?t=signed',
                expiresAt: DateTime.utc(2026, 10, 26),
              );
            },
      );

      final batch = await service.linksFor([
        _entry(id: 'river', audio: file.path),
        _entry(id: 'note', audio: '${dir.path}/note.txt'),
      ]);

      expect(batch.urls.keys, ['river']);
      expect(batch.skipped, 0);
      expect(uploaded, isNotNull);
      final url = batch.urls['river']!;
      expect(
        url.startsWith('https://example.com/api/export/audio-qr?t=signed#k='),
        isTrue,
      );
      final opened = await AesGcm.with256bits().decrypt(
        SecretBox(
          uploaded!,
          nonce: base64Decode(uploadedNonce!),
          mac: Mac(base64Decode(uploadedMac!)),
        ),
        secretKey: SecretKey(_base64Url(url.split('#k=').last)),
      );
      expect(opened, plain);
      await dir.delete(recursive: true);
    },
  );

  test(
    'a failed upload is skipped and the recording stays off the page',
    () async {
      final dir = await Directory.systemTemp.createTemp('audio_qr_');
      final file = File('${dir.path}/moment.m4a');
      await file.writeAsBytes([1, 2, 3]);
      final service = QrAudioService(
        upload:
            ({
              required String entryId,
              required List<int> ciphertext,
              required String nonce,
              required String mac,
            }) async => null,
      );
      final batch = await service.linksFor([
        _entry(id: 'river', audio: file.path),
        _entry(id: 'missing', audio: '${dir.path}/gone.m4a'),
      ]);
      expect(batch.urls, isEmpty);
      expect(batch.skipped, 2);
      await dir.delete(recursive: true);
    },
  );
}

List<int> _base64Url(String value) {
  final pad = value.padRight(value.length + (4 - value.length % 4) % 4, '=');
  return base64Url.decode(pad);
}
