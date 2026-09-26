import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/multipart_file_part.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:cryptography/cryptography.dart';
import 'package:http_parser/http_parser.dart';

/// AES-GCM seal for one recording. The key stays on the device and in the
/// printed link fragment, so the server only stores ciphertext.
class SealedAudio {
  const SealedAudio({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
    required this.key,
  });

  final List<int> ciphertext;
  final List<int> nonce;
  final List<int> mac;
  final List<int> key;
}

class QrAudioLink {
  const QrAudioLink({required this.url, required this.expiresAt});

  final String url;
  final DateTime expiresAt;
}

class QrAudioBatch {
  const QrAudioBatch({required this.urls, required this.skipped});

  final Map<String, String> urls;
  final int skipped;
}

/// Uploads a sealed `.m4a` and returns the signed link the server issued.
typedef QrAudioUploader =
    Future<QrAudioLink?> Function({
      required String entryId,
      required List<int> ciphertext,
      required String nonce,
      required String mac,
    });

/// Turns a local recording into a 30-day playable QR target.
class QrAudioService {
  QrAudioService({required this.upload});

  final QrAudioUploader upload;

  static QrAudioService http(HttpTransport transport) {
    return QrAudioService(
      upload:
          ({
            required String entryId,
            required List<int> ciphertext,
            required String nonce,
            required String mac,
          }) async {
            final result = await transport.postMultipart(
              VoiceMemoryApiRoutes.exportAudioQr.path,
              fields: {
                'entryId': entryId,
                'nonce': nonce,
                'mac': mac,
              },
              files: [
                MultipartFilePart.fromBytes(
                  field: 'audio',
                  bytes: ciphertext,
                  filename: 'recording.bin',
                  contentType: MediaType('application', 'octet-stream'),
                ),
              ],
            );
            return result.when(
              success: (response) {
                final decoded = jsonDecode(response.body);
                if (decoded is! Map) return null;
                final url = decoded['url'];
                final expiresAt = decoded['expiresAt'];
                if (url is! String || url.isEmpty) return null;
                if (expiresAt is! String) return null;
                final expiry = DateTime.tryParse(expiresAt);
                if (expiry == null) return null;
                return QrAudioLink(url: url, expiresAt: expiry.toUtc());
              },
              onFailure: (_) => null,
            );
          },
    );
  }

  Future<QrAudioBatch> linksFor(List<JournalEntry> entries) async {
    final urls = <String, String>{};
    var skipped = 0;
    for (final entry in entries) {
      final path = entry.localAudioPath?.trim();
      if (path == null ||
          path.isEmpty ||
          !path.toLowerCase().endsWith('.m4a')) {
        continue;
      }
      final file = File(path);
      if (!await file.exists()) {
        skipped += 1;
        continue;
      }
      final sealed = await sealAudio(await file.readAsBytes());
      final link = await upload(
        entryId: entry.id,
        ciphertext: sealed.ciphertext,
        nonce: base64Encode(sealed.nonce),
        mac: base64Encode(sealed.mac),
      );
      if (link == null) {
        skipped += 1;
        continue;
      }
      urls[entry.id] = playableAudioQrUrl(link.url, sealed.key);
    }
    return QrAudioBatch(urls: urls, skipped: skipped);
  }
}

Future<SealedAudio> sealAudio(List<int> plaintext) async {
  final algorithm = AesGcm.with256bits();
  final secretKey = await algorithm.newSecretKey();
  final box = await algorithm.encrypt(plaintext, secretKey: secretKey);
  return SealedAudio(
    ciphertext: box.cipherText,
    nonce: box.nonce,
    mac: box.mac.bytes,
    key: await secretKey.extractBytes(),
  );
}

/// Appends the decryption key as a URL fragment. Fragments are not sent to
/// the server when the code is opened.
String playableAudioQrUrl(String url, List<int> key) {
  final encoded = base64Url.encode(key).replaceAll('=', '');
  final withoutFragment = url.split('#').first;
  return '$withoutFragment#k=$encoded';
}
