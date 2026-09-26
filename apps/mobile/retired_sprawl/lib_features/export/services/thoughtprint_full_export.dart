import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:archiveme_mobile/features/export/archive_book_exporter.dart';
import 'package:archiveme_mobile/features/export/journal_bulk_export_service.dart';
import 'package:archiveme_mobile/features/export/obsidian_archive_exporter.dart';
import 'package:archiveme_mobile/features/export/services/zip_archiver_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/security/caregiver_session_guard.dart';
import 'package:crypto/crypto.dart';

/// One portable zip: `thoughtprint-export-YYYY-MM-DD.zip`.
abstract final class ThoughtprintFullExport {
  ThoughtprintFullExport._();

  static String fileName(DateTime day) {
    final utc = day.toUtc();
    final month = utc.month.toString().padLeft(2, '0');
    final date = utc.day.toString().padLeft(2, '0');
    return 'thoughtprint-export-${utc.year}-$month-$date.zip';
  }

  /// Stages the archive on disk and streams it into [outputDirectory].
  static Future<File> write({
    required List<JournalEntry> entries,
    required Directory outputDirectory,
    DateTime? exportedAt,
    bool includeBook = false,
    List<int>? bookPdf,
    void Function(double progress)? onProgress,
  }) async {
    await CaregiverSessionGuard.assertOwnerAccess(
      CaregiverSessionGuard.exportJournalBulk,
    );
    final clock = (exportedAt ?? DateTime.now()).toUtc();
    final active = entries.where((entry) => !entry.isDeleted).toList();
    final staging = await outputDirectory.createTemp('thoughtprint-export-');
    try {
      onProgress?.call(0.05);
      final rows = [
        for (final entry in active) JournalBulkExportPayload.archiveEntry(entry),
      ];
      final journal = const JsonEncoder.withIndent('  ').convert({
        'format': 'archiveme_journal_export_v1',
        'exportedAt': clock.toIso8601String(),
        'entryCount': rows.length,
        'entries': rows,
      });
      await File('${staging.path}/journal.json').writeAsString(journal);
      await File('${staging.path}/README.md').writeAsString(
        _readme(
          entryCount: rows.length,
          exportedAt: clock,
          includeBook: includeBook && bookPdf != null,
        ),
      );
      await _copyMedia(staging, active);
      onProgress?.call(0.45);
      final notes = ObsidianArchiveExporter.markdownDocuments(
        entries: [
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
              audioFileName: _audioHref(entry),
              photoFileNames: _photoHrefs(entry),
            ),
        ],
        directory: 'markdown',
        preserveMediaLinks: true,
      );
      for (final note in notes.entries) {
        final file = File('${staging.path}/${note.key}');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(note.value);
      }
      if (includeBook && bookPdf != null) {
        await File('${staging.path}/book.pdf').writeAsBytes(bookPdf);
      }
      onProgress?.call(0.6);
      final zip = File('${outputDirectory.path}/${fileName(clock)}');
      if (await zip.exists()) await zip.delete();
      await _zipInIsolate(
        sourcePath: staging.path,
        zipPath: zip.path,
        onProgress: (value) => onProgress?.call(0.6 + (value * 0.4)),
      );
      onProgress?.call(1);
      return zip;
    } finally {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  }

  /// Restores entries and media from a thoughtprint export zip.
  static Future<List<RestoredThoughtprintEntry>> read(
    File zip,
    Directory mediaRoot,
  ) async {
    final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    return _restore(archive, mediaRoot);
  }

  static List<RestoredThoughtprintEntry> readBytes(
    List<int> bytes,
    Directory mediaRoot,
  ) {
    return _restore(ZipDecoder().decodeBytes(bytes), mediaRoot);
  }

  static String? _audioHref(JournalEntry entry) {
    final name = JournalBulkExportPayload.archiveEntry(entry)['audio_file'];
    if (name is! String) return null;
    return '../$name';
  }

  static List<String> _photoHrefs(JournalEntry entry) {
    final images = JournalBulkExportPayload.archiveEntry(entry)['images'];
    if (images is! List) return const [];
    return [
      for (final path in images) '../$path',
    ];
  }

  static Future<void> _copyMedia(
    Directory staging,
    List<JournalEntry> entries,
  ) async {
    for (final entry in entries) {
      final row = JournalBulkExportPayload.archiveEntry(entry);
      final audioName = row['audio_file'];
      final audioPath = entry.audioUrl;
      if (audioName is String && audioPath != null) {
        await _copyIfExists(audioPath, File('${staging.path}/$audioName'));
      }
      final images = row['images'];
      if (images is! List) continue;
      final sources = [
        for (final image in entry.images)
          if (ZipArchiverService.photoFileName(image) != null) image,
      ];
      for (var i = 0; i < images.length && i < sources.length; i++) {
        await _copyIfExists(
          sources[i],
          File('${staging.path}/${images[i]}'),
        );
      }
    }
  }

  static Future<void> _copyIfExists(String sourcePath, File destination) async {
    final source = File(sourcePath);
    if (!await source.exists()) return;
    await destination.parent.create(recursive: true);
    final input = source.openRead();
    final output = destination.openWrite();
    await input.pipe(output);
  }

  static Future<void> _zipInIsolate({
    required String sourcePath,
    required String zipPath,
    required void Function(double progress) onProgress,
  }) async {
    final port = ReceivePort();
    try {
      await Isolate.spawn(_zipIsolate, [sourcePath, zipPath, port.sendPort]);
      await for (final message in port) {
        if (message is double) {
          onProgress(message);
          continue;
        }
        if (message == 'done') return;
        if (message is String && message.startsWith('error:')) {
          throw StateError(message.substring(6));
        }
      }
    } finally {
      port.close();
    }
  }

  static String _readme({
    required int entryCount,
    required DateTime exportedAt,
    required bool includeBook,
  }) {
    return '''
# Thoughtprint export

Exported: ${exportedAt.toIso8601String()}
Entries: $entryCount

This zip is a copy of the journal. Paths inside it are relative to this folder.

## Folders

- `journal.json` — every entry, with every saved field. A recording is `audio/<entryId>.m4a`. Photos are `photos/<entryId>/<n>.jpg`.
- `markdown/` — one note per entry. The note embeds the recording and the photos.
- `audio/` — the `.m4a` recordings.
- `photos/` — the full-size `.jpg` photos.
- `README.md` — this file.
${includeBook ? '- `book.pdf` — a printable copy of the journal.\n' : ''}
''';
  }

  static List<RestoredThoughtprintEntry> _restore(
    Archive archive,
    Directory mediaRoot,
  ) {
    final journalFile = archive.findFile('journal.json');
    if (journalFile == null) return const [];
    final decoded = jsonDecode(utf8.decode(journalFile.content as List<int>));
    if (decoded is! Map) return const [];
    final rows = decoded['entries'];
    if (rows is! List) return const [];
    final restored = <RestoredThoughtprintEntry>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final id = '${row['id'] ?? ''}';
      final transcript = '${row['transcript'] ?? ''}';
      final createdRaw = row['createdAt'];
      final createdAt = createdRaw is String ? DateTime.tryParse(createdRaw) : null;
      String? audioPath;
      final audioName = row['audio_file'];
      if (audioName is String) {
        audioPath = _extract(archive, audioName, mediaRoot);
      }
      final photos = <String>[];
      final images = row['images'];
      if (images is List) {
        for (final image in images) {
          if (image is! String) continue;
          final path = _extract(archive, image, mediaRoot);
          if (path != null) photos.add(path);
        }
      }
      restored.add(
        RestoredThoughtprintEntry(
          id: id,
          transcript: transcript,
          createdAt: createdAt,
          audioPath: audioPath,
          photoPaths: photos,
        ),
      );
    }
    return restored;
  }

  static String? _extract(Archive archive, String name, Directory mediaRoot) {
    final file = archive.findFile(name);
    if (file == null || !file.isFile) return null;
    final destination = File('${mediaRoot.path}/$name');
    destination.parent.createSync(recursive: true);
    destination.writeAsBytesSync(file.content as List<int>);
    return destination.path;
  }
}

class RestoredThoughtprintEntry {
  const RestoredThoughtprintEntry({
    required this.id,
    required this.transcript,
    required this.createdAt,
    required this.audioPath,
    required this.photoPaths,
  });

  final String id;
  final String transcript;
  final DateTime? createdAt;
  final String? audioPath;
  final List<String> photoPaths;

  String? get audioHash => _hash(audioPath);

  List<String> get photoHashes => [
    for (final path in photoPaths) _hash(path) ?? '',
  ];

  static String? _hash(String? path) {
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return sha256.convert(file.readAsBytesSync()).toString();
  }
}

Future<void> _zipIsolate(List<Object> args) async {
  final sourcePath = args[0] as String;
  final zipPath = args[1] as String;
  final send = args[2] as SendPort;
  try {
    final encoder = ZipFileEncoder();
    await encoder.zipDirectory(
      Directory(sourcePath),
      filename: zipPath,
      onProgress: send.send,
    );
    send.send('done');
  } on Object catch (error) {
    send.send('error: $error');
  }
}
