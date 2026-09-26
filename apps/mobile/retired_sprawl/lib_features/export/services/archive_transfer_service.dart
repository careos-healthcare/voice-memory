import 'dart:typed_data';

import 'package:archiveme_mobile/core/crypto/passphrase_vault.dart';
import 'package:archiveme_mobile/features/export/full_archive_transfer.dart';
import 'package:archiveme_mobile/features/export/services/zip_archiver_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Passphrase-sealed journal transfer. Recordings go in `audio/` and
/// full-size photos go in `photos/`.
abstract final class ArchiveTransferService {
  ArchiveTransferService._();

  static Future<Uint8List> exportZip({
    required PassphraseVault vault,
    required List<JournalEntry> entries,
  }) async {
    final packed = await ZipArchiverService.packEntries(entries);
    return FullArchiveTransfer.exportZip(
      vault: vault,
      entries: [
        for (final entry in entries)
          ArchiveTransferEntry(
            id: entry.id,
            createdAt: entry.createdAt,
            transcript: entry.transcript,
            tags: [
              if (entry.captureContextTag != null &&
                  entry.captureContextTag!.trim().isNotEmpty)
                entry.captureContextTag!.trim(),
            ],
            mood: entry.reflection.mood.trim().isEmpty
                ? null
                : entry.reflection.mood.trim(),
            place: entry.display.locationLabel,
            audioFileName: ZipArchiverService.relativeAudio(entry.audioUrl),
            photoFileNames: ZipArchiverService.relativePhotos(entry.images),
          ),
      ],
      audio: packed.audioByName,
      photos: packed.photosByName,
    );
  }
}
