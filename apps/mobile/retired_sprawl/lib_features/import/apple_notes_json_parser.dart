import 'dart:convert';

import 'package:archiveme_mobile/features/import/import_record.dart';
import 'package:archiveme_mobile/features/import/import_source.dart';
import 'package:archiveme_mobile/services/backlog_import_service.dart';

/// Parses Apple Notes structured JSON exports.
///
/// Expected shape:
/// `{ "notes": [{ "title": "...", "body": "...", "createdAt": "..." }] }`
/// or a top-level array of note objects.
abstract final class AppleNotesJsonParser {
  AppleNotesJsonParser._();

  static List<ExternalImportRecord> parse(
    String content, {
    required String sourceFile,
  }) {
    final dynamic decoded = jsonDecode(content);
    final rows = _extractNotes(decoded);
    if (rows.isEmpty) return const [];

    return rows
        .map((row) => _recordFromRow(row, sourceFile: sourceFile))
        .where((record) => record.text.trim().isNotEmpty)
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _extractNotes(dynamic decoded) {
    if (decoded is List) {
      return decoded.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (decoded is Map<String, dynamic>) {
      for (final key in ['notes', 'items', 'entries']) {
        final value = decoded[key];
        if (value is List) {
          return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
        }
      }
    }
    return const [];
  }

  static ExternalImportRecord _recordFromRow(
    Map<String, dynamic> row, {
    required String sourceFile,
  }) {
    final title = row['title']?.toString().trim() ?? '';
    final body = row['body']?.toString().trim() ??
        row['content']?.toString().trim() ??
        row['text']?.toString().trim() ??
        '';
    final text = title.isEmpty ? body : (body.isEmpty ? title : '$title\n\n$body');
    final createdRaw = row['createdAt']?.toString() ??
        row['creationDate']?.toString() ??
        row['date']?.toString();
    final createdAt =
        createdRaw == null ? null : DateTime.tryParse(createdRaw)?.toUtc();

    return ExternalImportRecord(
      source: ExternalImportSource.appleNotesJson,
      sourceFile: sourceFile,
      text: text,
      createdAt: createdAt,
      externalId: row['id']?.toString(),
    );
  }
}

/// CSV/plain-text adapters reuse the backlog import parsers.
List<ExternalImportRecord> parseAppleNotesCsvRecords(
  String content, {
  required String sourceFile,
}) {
  return parseAppleNotesCsv(content, sourceFile: sourceFile)
      .map(
        (chunk) => ExternalImportRecord(
          source: ExternalImportSource.appleNotesCsv,
          sourceFile: sourceFile,
          text: chunk.rawText ?? '',
          createdAt: chunk.createdAt,
          externalId: chunk.entryId,
        ),
      )
      .where((record) => record.text.trim().isNotEmpty)
      .toList(growable: false);
}

List<ExternalImportRecord> parsePlainTextRecords(
  String content, {
  required String sourceFile,
}) {
  return parseRawTextDump(content, sourceFile: sourceFile)
      .map(
        (chunk) => ExternalImportRecord(
          source: ExternalImportSource.plainText,
          sourceFile: sourceFile,
          text: chunk.rawText ?? '',
          createdAt: chunk.createdAt,
          externalId: chunk.entryId,
        ),
      )
      .where((record) => record.text.trim().isNotEmpty)
      .toList(growable: false);
}