import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archiveme_mobile/features/export/archive_book_exporter.dart';

/// One Markdown note per entry, plus audio files, in a zip for Obsidian.
abstract final class ObsidianArchiveExporter {
  ObsidianArchiveExporter._();

  static Uint8List buildZip({
    required List<ArchiveBookEntry> entries,
    DateTime? start,
    DateTime? end,
    Map<String, List<int>> audioByFileName = const {},
  }) {
    final selected = ArchiveBookExporter.inRange(
      entries: entries,
      start: start,
      end: end,
    );
    final archive = Archive();
    for (final entry in selected) {
      final name = _noteName(entry);
      final markdown = _markdown(entry);
      final bytes = utf8.encode(markdown);
      archive.addFile(ArchiveFile('notes/$name', bytes.length, bytes));
      final audioName = entry.audioFileName;
      final audio = audioName == null ? null : audioByFileName[audioName];
      if (audioName != null && audio != null) {
        archive.addFile(
          ArchiveFile('audio/$audioName', audio.length, audio),
        );
      }
    }
    final zipped = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipped);
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
    final audio = entry.audioFileName;
    if (audio != null && audio.isNotEmpty) {
      buffer.writeln('audio: $audio');
    }
    buffer
      ..writeln('---')
      ..writeln()
      ..writeln(entry.transcript.trim());
    return buffer.toString();
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
