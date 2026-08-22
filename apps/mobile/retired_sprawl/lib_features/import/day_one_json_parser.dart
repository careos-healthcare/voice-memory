import 'dart:convert';

import 'package:archiveme_mobile/features/import/import_record.dart';
import 'package:archiveme_mobile/features/import/import_source.dart';

/// Parses Day One JSON exports into [ExternalImportRecord] rows.
abstract final class DayOneJsonParser {
  DayOneJsonParser._();

  static List<ExternalImportRecord> parse(
    String content, {
    required String sourceFile,
  }) {
    final dynamic decoded = jsonDecode(content);
    final entries = _extractEntries(decoded);
    if (entries.isEmpty) return const [];

    return entries
        .map((row) => _recordFromRow(row, sourceFile: sourceFile))
        .where((record) => record.text.trim().isNotEmpty)
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _extractEntries(dynamic decoded) {
    if (decoded is List) {
      return decoded.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (decoded is Map<String, dynamic>) {
      for (final key in ['entries', 'journal', 'items', 'data']) {
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
    final text = _readText(row);
    final createdAt = _readDate(row);
    final externalId = row['uuid']?.toString() ??
        row['id']?.toString() ??
        row['identifier']?.toString();

    return ExternalImportRecord(
      source: ExternalImportSource.dayOneJson,
      sourceFile: sourceFile,
      text: text,
      createdAt: createdAt,
      externalId: externalId,
    );
  }

  static String _readText(Map<String, dynamic> row) {
    for (final key in ['text', 'body', 'content', 'markdown', 'richText']) {
      final value = row[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    final title = row['title']?.toString().trim() ?? '';
    return title;
  }

  static DateTime? _readDate(Map<String, dynamic> row) {
    for (final key in [
      'creationDate',
      'createdAt',
      'date',
      'creation',
      'modifiedDate',
    ]) {
      final value = row[key];
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed.toUtc();
      }
      if (value is num) {
        // Day One sometimes stores seconds since epoch.
        final millis = value > 1e12 ? value.toInt() : (value * 1000).toInt();
        return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      }
    }
    return null;
  }
}