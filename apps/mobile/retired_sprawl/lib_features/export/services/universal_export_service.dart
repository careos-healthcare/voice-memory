import 'dart:convert';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/export/archive_book_exporter.dart';
import 'package:archiveme_mobile/features/export/journal_bulk_export_service.dart';
import 'package:archiveme_mobile/features/export/obsidian_archive_exporter.dart';
import 'package:archiveme_mobile/features/export/services/zip_archiver_service.dart';
import 'package:archiveme_mobile/features/memory_transparency/memory_transparency_catalog.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/security/caregiver_session_guard.dart';

/// One zip with the journal, a note for each entry, recordings, and photos.
abstract final class UniversalExportService {
  UniversalExportService._();

  static const suggestedFileName = 'thoughtprint-everything.zip';

  static Future<Uint8List> buildZip({
    required List<JournalEntry> entries,
    MemoryTransparencyCatalog catalog = const MemoryTransparencyCatalog(),
    List<SurfacedInsightRecord>? insights,
    DateTime? exportedAt,
  }) async {
    await CaregiverSessionGuard.assertOwnerAccess(
      CaregiverSessionGuard.exportJournalBulk,
    );
    final active = entries.where((entry) => !entry.isDeleted).toList();
    final payload = JournalBulkExportPayload.fromEntries(
      entries: active,
      insights: insights ?? catalog.build(entries: active),
      exportedAt: exportedAt,
    );
    final notes = [
      for (final entry in active)
        ArchiveBookEntry(
          id: entry.id,
          recordedAt: entry.createdAt,
          transcript: entry.transcript,
          tags: [
            if (entry.captureContextTag != null &&
                entry.captureContextTag!.trim().isNotEmpty)
              entry.captureContextTag!.trim(),
          ],
          audioFileName: ZipArchiverService.audioFileName(entry.audioUrl),
          photoFileNames: ZipArchiverService.photoFileNames(entry.images),
        ),
    ];
    final packed = await ZipArchiverService.packEntries(active);
    return ZipArchiverService.encode(
      documents: {
        'journal.json': utf8.encode(payload.toJsonString()),
        'README.md': utf8.encode(
          readme(entryCount: payload.entryCount, exportedAt: payload.exportedAt),
        ),
        ...ObsidianArchiveExporter.markdownDocuments(
          entries: notes,
          directory: 'markdown',
        ),
      },
      audio: packed.audioByName,
      photos: packed.photosByName,
    );
  }

  /// How the zip is laid out, and how to read `journal.json`.
  static String readme({
    required int entryCount,
    required DateTime exportedAt,
  }) {
    return '''
# Thoughtprint export

Exported: ${exportedAt.toUtc().toIso8601String()}
Entries: $entryCount

This zip is a copy of the journal you can open on any computer. Paths inside it are relative to this folder. It does not contain locations on the phone that created it.

## Folders

- `journal.json` — every entry in one file.
- `markdown/` — one note per entry, with the date and tags at the top. A recording or photo is linked from the note.
- `audio/` — the `.m4a` recordings.
- `photos/` — the full-size `.jpg` photos. Small preview images are left out.
- `README.md` — this file.

## How to read journal.json

The file is UTF-8 JSON. The top-level fields are:

- `format` — `archiveme_journal_export_v1`.
- `exportedAt` — when this copy was made, in UTC.
- `entryCount` — how many entries are in `entries`.
- `entries` — the journal. Each object has `id`, `createdAt`, `updatedAt`, `transcript`, `reflection`, and `isArchived`.
- `insights` — short notes about the archive as a whole. Each has `id`, `kind`, `title`, `confidenceBand`, and `sourceCount`.

A recording is named by `audio_file`, for example `audio/note.m4a`. Photos are listed in `images`, for example `["photos/shot.jpg"]`. Those strings are paths inside this zip. Open the file next to the `audio` and `photos` folders and the names match.

`reflection` holds the mood and the words saved with the entry: `mood`, `emotionalIntensity`, `recurringThemes`, `exactLanguagePattern`, `concreteObservation`, and `repeatedSignal`.
''';
  }
}
