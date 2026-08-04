import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'disaster_recovery_core.dart';

final class ArchiveDisasterRecoveryZipCodec
    implements DisasterRecoveryZipCodec {
  const ArchiveDisasterRecoveryZipCodec();

  @override
  Future<Uint8List> encode(Map<String, Uint8List> entries) async {
    final archive = Archive();
    for (final entry in entries.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  @override
  Future<Map<String, Uint8List>> decode(Uint8List zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
    if (archive.files.isEmpty && zipBytes.isNotEmpty) {
      throw const FormatException('ZIP archive contains no files.');
    }
    final decoded = <String, Uint8List>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      if (decoded.containsKey(file.name)) {
        throw DisasterRecoveryFormatException(
          'Duplicate archive path: ${file.name}.',
        );
      }
      decoded[file.name] = Uint8List.fromList(file.content as List<int>);
    }
    return decoded;
  }
}
