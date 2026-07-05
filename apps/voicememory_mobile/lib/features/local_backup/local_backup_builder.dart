import 'dart:convert';

import '../../models/journal_entry.dart';
import '../../storage/journal_store.dart';
import '../../storage/mobile_prefs_store.dart';
import 'local_backup_model.dart';

/// Builds and validates local ArchiveMe backup payloads — JSON, not encrypted.
abstract final class LocalBackupBuilder {
  LocalBackupBuilder._();

  static const _forbiddenTopLevelKeys = {
    'device_id',
    'deviceId',
    'revenuecat',
    'customer_info',
    'customerInfo',
    'billing',
    'debug_logs',
    'debugLogs',
    'analytics',
    'archiveBetaFeedback',
    'beta_activation_summary_counts_v1',
    'beta_activation_loop_counts_v1',
    'archiveActivationFunnel',
    'entitlements.json',
  };

  static Future<Map<String, dynamic>> build({
    required JournalStore journal,
    required MobilePrefsStore prefs,
  }) async {
    final entries = await journal.loadAll();
    final journalEntries = entries.map(_entryForExport).toList();
    final prefsBackup = await _readIncludedPrefs(prefs);

    return {
      'archive_backup_version': archiveBackupVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'journal_entries': journalEntries,
      'prefs': prefsBackup,
    };
  }

  static Future<String> buildJson({
    required JournalStore journal,
    required MobilePrefsStore prefs,
  }) async {
    final payload = await build(journal: journal, prefs: prefs);
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static LocalArchiveBackupValidationResult validateJson(String raw) {
    if (raw.trim().isEmpty) {
      return const LocalArchiveBackupValidationResult.invalid(
        LocalArchiveBackupValidationFailure.notMap,
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const LocalArchiveBackupValidationResult.invalid(
          LocalArchiveBackupValidationFailure.notMap,
        );
      }
      return validateMap(decoded);
    } catch (_) {
      return const LocalArchiveBackupValidationResult.invalid(
        LocalArchiveBackupValidationFailure.notMap,
      );
    }
  }

  static LocalArchiveBackupValidationResult validateMap(
    Map<String, dynamic> raw,
  ) {
    for (final key in raw.keys) {
      if (_forbiddenTopLevelKeys.contains(key)) {
        return const LocalArchiveBackupValidationResult.invalid(
          LocalArchiveBackupValidationFailure.invalidPrefs,
        );
      }
    }

    final version = raw['archive_backup_version'];
    if (version is! num || version.toInt() != archiveBackupVersion) {
      return const LocalArchiveBackupValidationResult.invalid(
        LocalArchiveBackupValidationFailure.wrongVersion,
      );
    }

    final entriesRaw = raw['journal_entries'];
    if (entriesRaw is! List) {
      return const LocalArchiveBackupValidationResult.invalid(
        LocalArchiveBackupValidationFailure.invalidJournal,
      );
    }

    final entries = <JournalEntry>[];
    for (final item in entriesRaw) {
      if (item is! Map<String, dynamic>) {
        return const LocalArchiveBackupValidationResult.invalid(
          LocalArchiveBackupValidationFailure.invalidJournal,
        );
      }
      if (item.containsKey('localAudioPath')) {
        return const LocalArchiveBackupValidationResult.invalid(
          LocalArchiveBackupValidationFailure.invalidJournal,
        );
      }
      try {
        entries.add(entryForRestore(JournalEntry.fromJson(item)));
      } catch (_) {
        return const LocalArchiveBackupValidationResult.invalid(
          LocalArchiveBackupValidationFailure.invalidJournal,
        );
      }
    }

    final prefsRaw = raw['prefs'];
    if (prefsRaw is! Map) {
      return const LocalArchiveBackupValidationResult.invalid(
        LocalArchiveBackupValidationFailure.invalidPrefs,
      );
    }

    final prefs = <String, Map<String, dynamic>>{};
    for (final entry in prefsRaw.entries) {
      final key = entry.key.toString();
      if (LocalArchiveBackupPrefsKeys.excluded.contains(key) ||
          !LocalArchiveBackupPrefsKeys.included.contains(key)) {
        return const LocalArchiveBackupValidationResult.invalid(
          LocalArchiveBackupValidationFailure.invalidPrefs,
        );
      }
      final value = entry.value;
      if (value is! Map) {
        return const LocalArchiveBackupValidationResult.invalid(
          LocalArchiveBackupValidationFailure.invalidPrefs,
        );
      }
      prefs[key] = Map<String, dynamic>.from(value);
    }

    final exportedAtRaw = raw['exported_at'];
    final exportedAt = exportedAtRaw is String
        ? DateTime.tryParse(exportedAtRaw)?.toUtc()
        : null;

    return LocalArchiveBackupValidationResult.valid(
      LocalArchiveBackup(
        schemaVersion: archiveBackupVersion,
        exportedAt: exportedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        entries: entries,
        prefs: prefs,
      ),
    );
  }

  static Map<String, dynamic> _entryForExport(JournalEntry entry) {
    final json = entry.toJson();
    json.remove('localAudioPath');
    return json;
  }

  static JournalEntry entryForRestore(JournalEntry entry) => JournalEntry(
        id: entry.id,
        createdAt: entry.createdAt,
        transcript: entry.transcript,
        durationSeconds: entry.durationSeconds,
        reflection: entry.reflection,
        syncStatus: entry.syncStatus,
        treatAsNew: entry.treatAsNew,
        connectionApproved: entry.connectionApproved,
        keepExactDetails: entry.keepExactDetails,
        keepSeparate: entry.keepSeparate,
        archiveThreadId: entry.archiveThreadId,
        archivePackId: entry.archivePackId,
        isPinned: entry.isPinned,
        pinnedAt: entry.pinnedAt,
        isArchived: entry.isArchived,
        archivedAt: entry.archivedAt,
        entryAboutness: entry.entryAboutness,
        memorySurfacing: entry.memorySurfacing,
        preserveOriginal: entry.preserveOriginal,
        captureContextTag: entry.captureContextTag,
      );

  static Future<Map<String, Map<String, dynamic>>> _readIncludedPrefs(
    MobilePrefsStore prefs,
  ) async {
    final out = <String, Map<String, dynamic>>{};
    for (final key in LocalArchiveBackupPrefsKeys.included) {
      final map = await prefs.readMap(key) ?? await prefs.readJsonMap(key);
      if (map != null && map.isNotEmpty) {
        out[key] = Map<String, dynamic>.from(map);
      }
    }
    return out;
  }
}
