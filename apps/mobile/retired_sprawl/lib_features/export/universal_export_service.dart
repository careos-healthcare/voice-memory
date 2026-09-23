import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archiveme_mobile/core/execution/cancel_token.dart';
import 'package:archiveme_mobile/features/export/universal_export_markdown.dart';
import 'package:archiveme_mobile/features/export/universal_export_models.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

/// Builds a zip of Markdown moments, `archive_me.db`, and raw recordings.
class UniversalExportService {
  const UniversalExportService({this.share});

  static const databaseName = 'archive_me.db';
  static const zipName = 'archive_me_export.zip';

  final Future<void> Function(File file)? share;

  /// Measures Markdown, the database, and raw recordings before compression.
  Future<ExportSizeEstimate> estimate(UniversalExportRequest request) async {
    return _measure(request);
  }

  /// Writes the zip, then shares it or leaves it in the output directory.
  Future<File> export(
    UniversalExportRequest request, {
    ExecutionCancelToken? cancel,
    void Function(UniversalExportProgress progress)? onProgress,
    UniversalExportDelivery delivery = UniversalExportDelivery.save,
  }) async {
    final zip = _writeArchive(request, cancel: cancel, onProgress: onProgress);
    onProgress?.call(
      const UniversalExportProgress(label: 'Compressing', fraction: 1),
    );
    if (delivery == UniversalExportDelivery.share) {
      await (share ?? _shareSheet)(zip);
    }
    return zip;
  }

  /// Reads active journal rows, including location and tags when present.
  static Future<List<UniversalExportEntry>> readEntries(
    DatabaseExecutor db,
  ) async {
    List<Map<String, Object?>> rows;
    try {
      rows = await db.rawQuery('''
        SELECT id, created_at, updated_at, transcript, payload_json, ambient_metadata
        FROM journal_entries
        WHERE deleted_at IS NULL
        ORDER BY created_at
      ''');
    } on Object {
      rows = await db.rawQuery('''
        SELECT id, created_at, updated_at, transcript, payload_json
        FROM journal_entries
        WHERE deleted_at IS NULL
        ORDER BY created_at
      ''');
    }
    return [for (final row in rows) _entryFromRow(row)];
  }

  static Future<void> _shareSheet(File file) {
    return Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/zip')],
      subject: 'Archive export',
    );
  }

  static UniversalExportEntry _entryFromRow(Map<String, Object?> row) {
    final payload = _map(row['payload_json']);
    final ambient = _map(row['ambient_metadata']);
    final context = _nestedMap(payload, 'ambientContext');
    final locationMap = _nestedMap(ambient, 'location');
    final tags = <String>[];
    final contextTag = _string(payload['captureContextTag']);
    if (contextTag != null) tags.add(contextTag);
    final extraTags = payload['tags'];
    if (extraTags is List) {
      for (final tag in extraTags) {
        final value = _string(tag);
        if (value != null && !tags.contains(value)) tags.add(value);
      }
    }
    final location = _joinLocation(locationMap) ??
        _string(context['locality']) ??
        _string(payload['location']) ??
        '';
    final metadata = <String, Object?>{};
    final duration = payload['durationSeconds'];
    if (duration is num) metadata['durationSeconds'] = duration.round();
    final source = _string(payload['captureSource']);
    if (source != null) metadata['captureSource'] = source;
    final city = _string(locationMap['city']);
    if (city != null) metadata['city'] = city;
    final locality = _string(locationMap['locality']) ?? _string(context['locality']);
    if (locality != null) metadata['locality'] = locality;
    return UniversalExportEntry(
      id: row['id'] as String? ?? '',
      createdAt: _time(row['created_at']),
      updatedAt: row['updated_at'] == null ? null : _time(row['updated_at']),
      transcript: row['transcript'] as String? ?? '',
      tags: tags,
      location: location,
      audioPath: _string(payload['localAudioPath']),
      metadata: metadata,
    );
  }

  static ExportSizeEstimate _measure(UniversalExportRequest request) {
    var markdownBytes = 0;
    var audioBytes = 0;
    var sidecarBytes = 0;
    var recordingCount = 0;
    for (final entry in request.entries) {
      markdownBytes += utf8.encode(UniversalExportMarkdown.document(entry)).length;
      final recording = _recording(entry);
      if (recording == null) continue;
      recordingCount += 1;
      audioBytes += recording.bytes.length;
      sidecarBytes += utf8
          .encode(
            UniversalExportMarkdown.sidecar(entry, bytes: recording.bytes.length),
          )
          .length;
    }
    return ExportSizeEstimate(
      markdownBytes: markdownBytes,
      databaseBytes: request.databaseFile.lengthSync(),
      audioBytes: audioBytes,
      sidecarBytes: sidecarBytes,
      entryCount: request.entries.length,
      recordingCount: recordingCount,
    );
  }

  static File _writeArchive(
    UniversalExportRequest request, {
    ExecutionCancelToken? cancel,
    void Function(UniversalExportProgress progress)? onProgress,
  }) {
    cancel?.throwIfCancelled();
    final total = request.entries.length;
    final archive = Archive();
    for (var index = 0; index < request.entries.length; index++) {
      cancel?.throwIfCancelled();
      final entry = request.entries[index];
      final markdown = utf8.encode(UniversalExportMarkdown.document(entry));
      archive.addFile(
        ArchiveFile(_entryPath(entry.id, index), markdown.length, markdown),
      );
      onProgress?.call(
        UniversalExportProgress(
          label: 'Writing moments',
          fraction: total == 0 ? 0.3 : (index + 1) / total * 0.4,
        ),
      );
    }

    cancel?.throwIfCancelled();
    onProgress?.call(
      const UniversalExportProgress(label: 'Copying database', fraction: 0.5),
    );
    final databaseBytes = request.databaseFile.readAsBytesSync();
    archive.addFile(
      ArchiveFile(databaseName, databaseBytes.length, databaseBytes),
    );

    for (var index = 0; index < request.entries.length; index++) {
      cancel?.throwIfCancelled();
      final entry = request.entries[index];
      final recording = _recording(entry);
      if (recording == null) continue;
      final base = _safeId(entry.id, index);
      archive.addFile(
        ArchiveFile(
          'audio/$base.${recording.format}',
          recording.bytes.length,
          recording.bytes,
        ),
      );
      final sidecar = utf8.encode(
        UniversalExportMarkdown.sidecar(entry, bytes: recording.bytes.length),
      );
      archive.addFile(ArchiveFile('audio/$base.json', sidecar.length, sidecar));
      onProgress?.call(
        UniversalExportProgress(
          label: 'Copying recordings',
          fraction: 0.5 + ((index + 1) / (total == 0 ? 1 : total)) * 0.3,
        ),
      );
    }

    cancel?.throwIfCancelled();
    onProgress?.call(
      const UniversalExportProgress(label: 'Compressing', fraction: 0.9),
    );
    final encoded = ZipEncoder().encode(archive);
    return File('${request.outputDirectory.path}/$zipName')
      ..writeAsBytesSync(encoded, flush: true);
  }

  static _Recording? _recording(UniversalExportEntry entry) {
    final path = entry.audioPath;
    if (!UniversalExportMarkdown.isRawRecording(path)) return null;
    final file = File(path!);
    if (!file.existsSync()) return null;
    return _Recording(
      bytes: file.readAsBytesSync(),
      format: path.toLowerCase().endsWith('.wav') ? 'wav' : 'm4a',
    );
  }

  static String _entryPath(String id, int index) => 'entries/${_safeId(id, index)}.md';

  static String _safeId(String id, int index) {
    final cleaned = id.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    if (cleaned.isEmpty) return 'entry_$index';
    return cleaned;
  }

  static Map<String, Object?> _map(Object? raw) {
    if (raw is Map) return Map<String, Object?>.from(raw);
    if (raw is! String || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } on Object {
      return const {};
    }
    return const {};
  }

  static Map<String, Object?> _nestedMap(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is Map) return Map<String, Object?>.from(value);
    return const {};
  }

  static String? _joinLocation(Map<String, Object?> location) {
    final parts = <String>[
      if (_string(location['city']) != null) _string(location['city'])!,
      if (_string(location['locality']) != null) _string(location['locality'])!,
    ];
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime _time(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.round(), isUtc: true);
    }
    return DateTime.tryParse('$value')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}

class _Recording {
  const _Recording({required this.bytes, required this.format});

  final Uint8List bytes;
  final String format;
}
