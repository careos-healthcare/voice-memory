import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archiveme_mobile/core/crypto/passphrase_vault.dart';
import 'package:archiveme_mobile/features/export/services/zip_archiver_service.dart';

class ArchiveTransferEntry {
  const ArchiveTransferEntry({
    required this.id,
    required this.createdAt,
    required this.transcript,
    this.tags = const [],
    this.mood,
    this.place,
    this.audioFileName,
    this.photoFileNames = const [],
  });

  final String id;
  final DateTime createdAt;
  final String transcript;
  final List<String> tags;
  final String? mood;
  final String? place;
  final String? audioFileName;
  final List<String> photoFileNames;

  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'transcript': transcript,
    'tags': tags,
    'mood': mood,
    'place': place,
    'audioFileName': audioFileName,
    'photoFileNames': photoFileNames,
  };

  factory ArchiveTransferEntry.fromJson(Map<String, Object?> json) {
    return ArchiveTransferEntry(
      id: json['id'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      transcript: json['transcript'] as String? ?? '',
      tags: [
        for (final tag in (json['tags'] as List<Object?>? ?? const []))
          tag.toString(),
      ],
      mood: json['mood'] as String?,
      place: json['place'] as String?,
      audioFileName: json['audioFileName'] as String?,
      photoFileNames: [
        for (final name
            in (json['photoFileNames'] as List<Object?>? ?? const []))
          name.toString(),
      ],
    );
  }
}

class ArchiveBundle {
  const ArchiveBundle({
    required this.schemaVersion,
    required this.entries,
  });

  final int schemaVersion;
  final List<ArchiveTransferEntry> entries;
}

abstract final class FullArchiveTransfer {
  FullArchiveTransfer._();

  static const schemaVersion = 1;

  static Future<Uint8List> exportZip({
    required PassphraseVault vault,
    required List<ArchiveTransferEntry> entries,
    Map<String, List<int>> audio = const {},
    Map<String, List<int>> photos = const {},
  }) async {
    final journal = jsonEncode({
      'entries': entries.map((entry) => entry.toJson()).toList(),
    });
    final encrypted = await vault.encrypt(utf8.encode(journal));
    final manifest = jsonEncode({
      'schemaVersion': schemaVersion,
      'encryption': 'aes-256-gcm',
      'salt': encrypted.salt,
      'nonce': encrypted.nonce,
    });
    return ZipArchiverService.encode(
      documents: {
        'manifest.json': utf8.encode(manifest),
        'journal.json': base64Decode(encrypted.ciphertext),
      },
      audio: audio,
      photos: photos,
    );
  }

  static Future<ArchiveBundle> importZip({
    required PassphraseVault vault,
    required List<int> bytes,
  }) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final manifestFile = archive.findFile('manifest.json');
    final journalFile = archive.findFile('journal.json');
    if (manifestFile == null || journalFile == null) {
      throw const FormatException('Archive is missing manifest or journal.');
    }
    final manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>))
        as Map<String, Object?>;
    final version = manifest['schemaVersion'];
    if (version != schemaVersion) {
      throw FormatException('Unsupported archive schema $version.');
    }
    final clear = await vault.decrypt(
      CiphertextBlob(
        ciphertext: base64Encode(journalFile.content as List<int>),
        nonce: manifest['nonce'] as String,
        salt: manifest['salt'] as String,
      ),
    );
    final journal = jsonDecode(utf8.decode(clear)) as Map<String, Object?>;
    final entries = [
      for (final item in (journal['entries'] as List<Object?>? ?? const []))
        if (item is Map)
          ArchiveTransferEntry.fromJson(Map<String, Object?>.from(item)),
    ];
    return ArchiveBundle(schemaVersion: schemaVersion, entries: entries);
  }

  static List<ArchiveTransferEntry> merge(
    List<ArchiveTransferEntry> local,
    List<ArchiveTransferEntry> incoming,
  ) {
    final byId = {for (final entry in local) entry.id: entry};
    for (final entry in incoming) {
      final current = byId[entry.id];
      if (current == null || entry.createdAt.isAfter(current.createdAt)) {
        byId[entry.id] = entry;
      }
    }
    return byId.values.toList();
  }
}
