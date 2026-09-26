import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archiveme_mobile/features/moment_quality/post_save_moment_detail_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/security/caregiver_session_guard.dart';
import 'package:crypto/crypto.dart';

/// A Day One journal zip: `Journal.json`, `photos/{md5}.jpeg`, and `audio/{md5}.m4a`.
abstract final class DayOneExportService {
  DayOneExportService._();

  static const suggestedFileName = 'thoughtprint-day-one.zip';
  static const journalFileName = 'Journal.json';
  static const documentedEntryFields = [
    'uuid',
    'text',
    'creationDate',
    'photos',
    'audios',
  ];

  /// True when every entry has the fields Day One documents for a journal file.
  static bool matchesDocumentedFields(Map<String, dynamic> journal) {
    final entries = journal['entries'];
    if (entries is! List || entries.isEmpty) return false;
    for (final row in entries) {
      if (row is! Map) return false;
      for (final field in documentedEntryFields) {
        if (!row.containsKey(field)) return false;
      }
    }
    return true;
  }

  static Future<Uint8List> buildZip({
    required List<JournalEntry> entries,
  }) async {
    await CaregiverSessionGuard.assertOwnerAccess(
      CaregiverSessionGuard.exportJournalBulk,
    );
    final active = entries.where((entry) => !entry.isDeleted).toList();
    final followUps = _followUpsByParent(active);
    final parents = active.where((entry) => !_isFollowUp(entry, active));
    final archive = Archive();
    final rows = <Map<String, Object?>>[];
    for (final entry in parents) {
      rows.add(
        await _entryJson(
          entry,
          followUps: followUps[entry.id] ?? const [],
          archive: archive,
        ),
      );
    }
    final journal = const JsonEncoder.withIndent('  ').convert({
      'metadata': {'version': '1.0'},
      'entries': rows,
    });
    final journalBytes = utf8.encode(journal);
    archive.addFile(
      ArchiveFile(journalFileName, journalBytes.length, journalBytes),
    );
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static Map<String, List<JournalEntry>> _followUpsByParent(
    List<JournalEntry> entries,
  ) {
    final byId = {for (final entry in entries) entry.id: entry};
    final grouped = <String, List<JournalEntry>>{};
    for (final entry in entries) {
      final parentId = _parentId(entry);
      if (parentId == null || !byId.containsKey(parentId)) continue;
      grouped.putIfAbsent(parentId, () => []).add(entry);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return grouped;
  }

  static bool _isFollowUp(JournalEntry entry, List<JournalEntry> entries) {
    final parentId = _parentId(entry);
    if (parentId == null) return false;
    return entries.any((candidate) => candidate.id == parentId);
  }

  static String? _parentId(JournalEntry entry) {
    final tag = entry.captureContextTag ?? '';
    for (final type in PostSaveMomentDetailType.values) {
      final prefix = 'post_save_detail_${type.analyticsValue}_';
      if (tag.startsWith(prefix) && tag.length > prefix.length) {
        return tag.substring(prefix.length);
      }
    }
    return null;
  }

  static Future<Map<String, Object?>> _entryJson(
    JournalEntry entry, {
    required List<JournalEntry> followUps,
    required Archive archive,
  }) async {
    final photos = await _media(
      paths: entry.images,
      archive: archive,
      folder: 'photos',
      extension: 'jpeg',
      kind: 'photo',
    );
    final audio = await _media(
      paths: [if (entry.audioUrl != null) entry.audioUrl!],
      archive: archive,
      folder: 'audio',
      extension: 'm4a',
      kind: 'audio',
    );
    final location = _location(entry);
    return {
      'uuid': entry.id,
      'text': _text(entry, followUps),
      'creationDate': entry.createdAt.toUtc().toIso8601String(),
      'timeZone': 'UTC',
      if (location != null) 'location': location,
      'photos': photos,
      'audio': audio,
      'audios': audio,
    };
  }

  static String _text(JournalEntry entry, List<JournalEntry> followUps) {
    final parts = <String>[
      entry.transcript.trim(),
      for (final follow in followUps) follow.transcript.trim(),
    ].where((part) => part.isNotEmpty);
    return parts.join('\n\n');
  }

  static Map<String, Object>? _location(JournalEntry entry) {
    final latitude = entry.display.latitude;
    final longitude = entry.display.longitude;
    final place = entry.display.locationLabel?.trim();
    if (latitude == null || longitude == null) {
      if (place == null || place.isEmpty) return null;
      return {'placeName': place};
    }
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (place != null && place.isNotEmpty) 'placeName': place,
    };
  }

  static Future<List<Map<String, Object>>> _media({
    required List<String> paths,
    required Archive archive,
    required String folder,
    required String extension,
    required String kind,
  }) async {
    final objects = <Map<String, Object>>[];
    for (final path in paths) {
      if (kind == 'photo' && _isPreview(path)) continue;
      if (kind == 'audio' && !path.toLowerCase().trim().endsWith('.m4a')) {
        continue;
      }
      if (kind == 'photo' && !_isJpeg(path)) continue;
      final file = File(path);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final hash = md5.convert(bytes).toString();
      final name = '$folder/$hash.$extension';
      if (archive.findFile(name) == null) {
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }
      objects.add({
        'md5': hash,
        'identifier': hash,
        'orderInEntry': objects.length,
        if (kind == 'photo') 'type': 'jpeg',
        if (kind == 'audio') 'format': 'm4a',
      });
    }
    return objects;
  }

  static bool _isPreview(String path) {
    return path.toLowerCase().contains('_thumb.');
  }

  static bool _isJpeg(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg');
  }
}
