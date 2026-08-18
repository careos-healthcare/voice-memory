import 'dart:convert';

import 'package:archiveme_mobile/features/memory_transparency/memory_transparency_catalog.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';

/// Open-format journal export payload.
class JournalBulkExportPayload {
  const JournalBulkExportPayload({
    required this.exportedAt,
    required this.entryCount,
    required this.entries,
  });

  factory JournalBulkExportPayload.fromEntries({
    required List<JournalEntry> entries,
    required List<SurfacedInsightRecord> insights,
    DateTime? exportedAt,
  }) {
    final insightByEntry = <String, List<Map<String, dynamic>>>{};
    for (final insight in insights) {
      // Insights are archive-level; attach under synthetic key for portability.
      insightByEntry.putIfAbsent('_archive', () => []).add({
        'id': insight.id,
        'kind': insight.kind.name,
        'title': insight.title,
        'confidenceBand': insight.confidenceBand.name,
        'sourceCount': insight.sourceCount,
      });
    }

    final rows = [
      for (final entry in entries)
        {
          'id': entry.id,
          'createdAt': entry.createdAt.toUtc().toIso8601String(),
          'updatedAt': entry.updatedAt.toUtc().toIso8601String(),
          'transcript': entry.transcript,
          'reflection': entry.reflection.toJson(),
          'isArchived': entry.isArchived,
          if (entry.localAudioPath != null && entry.localAudioPath!.isNotEmpty)
            'localAudioPath': entry.localAudioPath,
          if (entry.proof.verifiedProof != null)
            'verifiedProof': entry.proof.verifiedProof!.toJson(),
        },
    ];

    return JournalBulkExportPayload(
      exportedAt: exportedAt ?? DateTime.now().toUtc(),
      entryCount: entries.length,
      entries: {
        'format': 'archiveme_journal_export_v1',
        'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'entryCount': entries.length,
        'entries': rows,
        'insights': insightByEntry['_archive'] ?? const [],
      },
    );
  }

  final DateTime exportedAt;
  final int entryCount;
  final Map<String, dynamic> entries;

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(entries);

  static JournalBulkExportPayload fromJsonString(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return JournalBulkExportPayload(
      exportedAt: DateTime.parse(decoded['exportedAt'] as String),
      entryCount: decoded['entryCount'] as int? ?? 0,
      entries: decoded,
    );
  }
}

/// Exports non-deleted journal rows via [JournalSqliteRepository].
class JournalBulkExportService {
  const JournalBulkExportService({
    required this.repository,
    this.catalog = const MemoryTransparencyCatalog(),
  });

  final JournalSqliteRepository repository;
  final MemoryTransparencyCatalog catalog;

  Future<JournalBulkExportPayload> buildExport() async {
    final entries = await repository.fetchAllActive();
    final insights = catalog.build(entries: entries);
    return JournalBulkExportPayload.fromEntries(
      entries: entries,
      insights: insights,
    );
  }
}
