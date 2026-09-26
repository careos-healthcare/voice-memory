import 'dart:convert';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/export/archive_book_exporter.dart';
import 'package:archiveme_mobile/features/export/services/zip_archiver_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// One Markdown note per entry, plus audio and photo files, in a zip for Obsidian.
abstract final class ObsidianArchiveExporter {
  ObsidianArchiveExporter._();

  static Future<Uint8List> buildZipFromJournal({
    required List<JournalEntry> entries,
    DateTime? start,
    DateTime? end,
  }) async {
    final books = [
      for (final entry in entries)
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
    final selected = ArchiveBookExporter.inRange(
      entries: books,
      start: start,
      end: end,
    );
    final ids = selected.map((entry) => entry.id).toSet();
    final packed = await ZipArchiverService.packEntries(
      entries.where((entry) => ids.contains(entry.id)),
    );
    return buildZip(
      entries: selected,
      audioByFileName: packed.audioByName,
      photosByFileName: packed.photosByName,
    );
  }

  static Uint8List buildZip({
    required List<ArchiveBookEntry> entries,
    DateTime? start,
    DateTime? end,
    Map<String, List<int>> audioByFileName = const {},
    Map<String, List<int>> photosByFileName = const {},
  }) {
    final selected = ArchiveBookExporter.inRange(
      entries: entries,
      start: start,
      end: end,
    );
    return ZipArchiverService.encode(
      documents: markdownDocuments(entries: selected),
      audio: audioByFileName,
      photos: photosByFileName,
    );
  }

  /// One Obsidian note per entry. [directory] is the folder inside the zip.
  static Map<String, List<int>> markdownDocuments({
    required List<ArchiveBookEntry> entries,
    String directory = 'notes',
  }) {
    return {
      for (final entry in entries)
        '$directory/${_noteName(entry)}': utf8.encode(_markdown(entry)),
    };
  }

  static String _markdown(ArchiveBookEntry entry) {
    final tags = entry.tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    final buffer = StringBuffer()
      ..writeln('---')
      ..writeln('date: ${_date(entry.recordedAt)}')
      ..writeln('tags:');
    if (tags.isEmpty) {
      buffer.writeln('  []');
    } else {
      for (final tag in tags) {
        buffer.writeln('  - $tag');
      }
    }
    final audio = _fileName(entry.audioFileName);
    if (audio != null) {
      buffer.writeln('audio: $audio');
    }
    buffer
      ..writeln('---')
      ..writeln()
      ..writeln(entry.transcript.trim());
    if (audio != null) {
      buffer
        ..writeln()
        ..writeln('![Audio](audio/$audio)');
    }
    for (final photo in entry.photoFileNames) {
      final name = _fileName(photo);
      if (name == null) continue;
      buffer.writeln('![[photos/$name]]');
    }
    return buffer.toString();
  }

  static String? _fileName(String? path) {
    if (path == null) return null;
    final name = path.trim().split(RegExp(r'[/\\]')).last;
    if (name.isEmpty) return null;
    return name;
  }

  static String _noteName(ArchiveBookEntry entry) {
    final safeId = entry.id.replaceAll(RegExp('[^A-Za-z0-9_-]'), '');
    return '${_date(entry.recordedAt)}-$safeId.md';
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
