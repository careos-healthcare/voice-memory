import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/features/import/apple_notes_json_parser.dart';
import 'package:archiveme_mobile/features/import/day_one_json_parser.dart';
import 'package:archiveme_mobile/features/import/import_record.dart';
import 'package:archiveme_mobile/features/import/journal_entry_importer.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:file_picker/file_picker.dart';

export 'journal_entry_importer.dart';

/// Structured JSON parsing for Day One / Apple Notes cold-start imports.
class ExternalImportCoordinator {
  ExternalImportCoordinator(this._store);

  final JournalStore _store;

  static const supportedExtensions = {'json', 'txt', 'csv'};

  Future<List<PlatformFile>> pickExportFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedExtensions.toList(),
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return const [];
    return result.files;
  }

  List<ExternalImportRecord> parseFiles(List<PlatformFile> files) {
    final records = <ExternalImportRecord>[];
    for (final file in files) {
      final content = _readText(file);
      if (content == null || content.trim().isEmpty) continue;
      records.addAll(parseFileContent(content, filename: file.name));
    }
    return records;
  }

  Future<JournalImportResult> importFiles(List<PlatformFile> files) async {
    final records = parseFiles(files);
    return JournalEntryImporter.persistAll(store: _store, records: records);
  }

  /// Detects source from filename + JSON shape.
  static List<ExternalImportRecord> parseFileContent(
    String content, {
    required String filename,
  }) {
    final extension = _extensionFor(filename);
    if (extension == 'csv') {
      return parseAppleNotesCsvRecords(content, sourceFile: filename);
    }
    if (extension == 'txt') {
      return parsePlainTextRecords(content, sourceFile: filename);
    }
    if (extension == 'json') {
      return _parseJson(content, sourceFile: filename);
    }
    return const [];
  }

  static List<ExternalImportRecord> _parseJson(
    String content, {
    required String sourceFile,
  }) {
    try {
      final dynamic decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('entries') ||
            decoded.containsKey('journal') ||
            _looksLikeDayOne(decoded)) {
          return DayOneJsonParser.parse(content, sourceFile: sourceFile);
        }
      }
      return AppleNotesJsonParser.parse(content, sourceFile: sourceFile);
    } catch (_, stackTrace) {
      return const [];
    }
  }

  static bool _looksLikeDayOne(Map<String, dynamic> root) {
    final entries = root['entries'];
    if (entries is! List || entries.isEmpty) return false;
    final first = entries.first;
    if (first is! Map) return false;
    return first.containsKey('creationDate') || first.containsKey('uuid');
  }

  static String? _extensionFor(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0) return null;
    return filename.substring(dot + 1).toLowerCase();
  }

  static String? _readText(PlatformFile file) {
    if (file.bytes != null) return utf8.decode(file.bytes!);
    final path = file.path;
    if (path == null || path.isEmpty) return null;
    return File(path).readAsStringSync();
  }
}