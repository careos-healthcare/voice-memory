import 'dart:convert';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/export/services/zip_archiver_service.dart';
import 'package:archiveme_mobile/features/memory_transparency/memory_transparency_catalog.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/security/caregiver_session_guard.dart';
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
          ...ZipArchiverService.portableMediaFields(
            audioPath: entry.audioUrl,
            images: entry.images,
          ),
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

  /// One entry for `journal.json`. Device paths are replaced with
  /// `audio/<id>.m4a` and `photos/<id>/<n>.jpg`.
  static Map<String, dynamic> archiveEntry(JournalEntry entry) {
    final row = jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>;
    _stripDevicePaths(row);
    final id = _safeId(entry.id);
    final audio = entry.audioUrl;
    if (audio != null && audio.toLowerCase().trim().endsWith('.m4a')) {
      row['audio_file'] = 'audio/$id.m4a';
    }
    final photos = <String>[];
    var index = 1;
    for (final image in entry.images) {
      if (ZipArchiverService.photoFileName(image) == null) continue;
      photos.add('photos/$id/$index.jpg');
      index += 1;
    }
    if (photos.isNotEmpty) row['images'] = photos;
    return row;
  }

  static String _safeId(String id) {
    final safe = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return safe.isEmpty ? 'entry' : safe;
  }

  static void _stripDevicePaths(Object? node) {
    if (node is Map) {
      for (final key in node.keys.toList()) {
        final value = node[key];
        if (key == 'localAudioPath' || key == 'audioUrl') {
          node.remove(key);
          continue;
        }
        if (value is String && _isDevicePath(value)) {
          node.remove(key);
          continue;
        }
        _stripDevicePaths(value);
      }
      return;
    }
    if (node is List) {
      node.removeWhere((item) => item is String && _isDevicePath(item));
      for (final item in node.toList()) {
        _stripDevicePaths(item);
      }
    }
  }

  static bool _isDevicePath(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('/') || trimmed.contains(r':\');
  }

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
    final entries = await _loadEntries();
    return JournalBulkExportPayload.fromEntries(
      entries: entries,
      insights: catalog.build(entries: entries),
    );
  }

  /// Journal JSON plus the recordings and full-size photos those entries name.
  Future<({JournalBulkExportPayload payload, Uint8List zipBytes})>
  buildZip() async {
    final entries = await _loadEntries();
    final payload = JournalBulkExportPayload.fromEntries(
      entries: entries,
      insights: catalog.build(entries: entries),
    );
    final packed = await ZipArchiverService.packEntries(entries);
    return (
      payload: payload,
      zipBytes: ZipArchiverService.encode(
        documents: {'journal.json': utf8.encode(payload.toJsonString())},
        audio: packed.audioByName,
        photos: packed.photosByName,
      ),
    );
  }

  Future<List<JournalEntry>> _loadEntries() async {
    await CaregiverSessionGuard.assertOwnerAccess(
      CaregiverSessionGuard.exportJournalBulk,
    );
    return repository.fetchAllActive();
  }
}
