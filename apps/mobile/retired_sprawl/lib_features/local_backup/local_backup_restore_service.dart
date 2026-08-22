import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/features/archive_controls/archive_exclusion_store.dart';
import 'package:archiveme_mobile/features/archive_history/archive_history_engine.dart';
import 'package:archiveme_mobile/features/entry_importance/entry_importance_store.dart';
import 'package:archiveme_mobile/features/first_proof_truth/first_proof_truth_store.dart';
import 'package:archiveme_mobile/features/helped_tracking/helped_tracking_store.dart';
import 'package:archiveme_mobile/features/local_backup/local_backup_analytics.dart';
import 'package:archiveme_mobile/features/local_backup/local_backup_builder.dart';
import 'package:archiveme_mobile/features/local_backup/local_backup_model.dart';
import 'package:archiveme_mobile/features/pattern_detail/pattern_detail_engine.dart';
import 'package:archiveme_mobile/features/pattern_naming/pattern_name_store.dart';
import 'package:archiveme_mobile/features/what_changed/what_changed_v2_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/security/local_privacy_data_controls.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum LocalBackupExportFailure { notInitialized, shareFailed }

enum LocalBackupRestoreFailure {
  notInitialized,
  pickerCancelled,
  invalidBackup,
  restoreFailed,
}

class LocalBackupExportResult {
  const LocalBackupExportResult.success({
    required this.entryCount,
    required this.schemaVersion,
  }) : failure = null;

  const LocalBackupExportResult.failure(this.failure)
    : entryCount = 0,
      schemaVersion = archiveBackupVersion;

  final LocalBackupExportFailure? failure;
  final int entryCount;
  final int schemaVersion;

  bool get succeeded => failure == null;
}

class LocalBackupRestoreResult {
  const LocalBackupRestoreResult.success({
    required this.entryCount,
    required this.schemaVersion,
  }) : failure = null,
       cancelled = false;

  const LocalBackupRestoreResult.cancelled()
    : failure = null,
      cancelled = true,
      entryCount = 0,
      schemaVersion = archiveBackupVersion;

  const LocalBackupRestoreResult.failure(
    this.failure, {
    int version = archiveBackupVersion,
  }) : cancelled = false,
       entryCount = 0,
       schemaVersion = version;

  final LocalBackupRestoreFailure? failure;
  final bool cancelled;
  final int entryCount;
  final int schemaVersion;

  bool get succeeded => failure == null && !cancelled;
}

typedef LocalBackupShareHook = Future<void> Function(String filePath);
typedef LocalBackupPickHook = Future<String?> Function();

/// Manual local backup export and restore — never uploads backup contents.
class LocalBackupRestoreService {
  LocalBackupRestoreService({
    this._journal,
    this._prefs,
    this._controls,
    this.shareBackupFile,
    this.pickBackupFile,
  });

  final JournalStore? _journal;
  final MobilePrefsStore? _prefs;
  final LocalPrivacyDataControls? _controls;
  final LocalBackupShareHook? shareBackupFile;
  final LocalBackupPickHook? pickBackupFile;

  JournalStore get journal => _journal ?? AppServices.instance.journalStore;
  MobilePrefsStore get prefs => _prefs ?? AppServices.instance.prefs;
  LocalPrivacyDataControls get controls =>
      _controls ?? LocalPrivacyDataControls.instance();

  Future<LocalBackupExportResult> exportBackup({required String source}) async {
    if (!AppServices.isInitialized) {
      return const LocalBackupExportResult.failure(
        LocalBackupExportFailure.notInitialized,
      );
    }

    try {
      final json = await LocalBackupBuilder.buildJson(
        journal: journal,
        prefs: prefs,
      );
      final payload = jsonDecode(json) as Map<String, dynamic>;
      final entriesRaw = payload['journal_entries'];
      final entryCount = entriesRaw is List ? entriesRaw.length : 0;

      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toUtc().toIso8601String().split('T').first;
      final file = File('${dir.path}/archiveme_backup_$stamp.json');
      await file.writeAsString(json);

      final share =
          shareBackupFile ??
          (path) => Share.shareXFiles([
            XFile(path, mimeType: 'application/json'),
          ], subject: 'ArchiveMe backup');
      await share(file.path);

      LocalBackupAnalytics.exported(
        source: source,
        hasEntries: entryCount > 0,
        schemaVersion: archiveBackupVersion,
      );

      return LocalBackupExportResult.success(
        entryCount: entryCount,
        schemaVersion: archiveBackupVersion,
      );
    } catch (_, stackTrace) {
      return const LocalBackupExportResult.failure(
        LocalBackupExportFailure.shareFailed,
      );
    }
  }

  Future<LocalBackupRestoreResult> pickAndRestoreBackup({
    required String source,
  }) async {
    if (!AppServices.isInitialized) {
      return const LocalBackupRestoreResult.failure(
        LocalBackupRestoreFailure.notInitialized,
      );
    }

    final raw = await pickBackupFileContent();
    if (raw == null) {
      return const LocalBackupRestoreResult.cancelled();
    }
    return restoreBackup(source: source, rawJson: raw);
  }

  Future<String?> pickBackupFileContent() async {
    final picked = pickBackupFile ?? _defaultPickBackupFile;
    return picked();
  }

  Future<LocalBackupRestoreResult> restoreBackup({
    required String source,
    required String rawJson,
  }) async {
    if (!AppServices.isInitialized) {
      return const LocalBackupRestoreResult.failure(
        LocalBackupRestoreFailure.notInitialized,
      );
    }

    final validation = LocalBackupBuilder.validateJson(rawJson);
    if (!validation.isValid || validation.backup == null) {
      LocalBackupAnalytics.restoreFailed(
        source: source,
        schemaVersion: archiveBackupVersion,
      );
      return const LocalBackupRestoreResult.failure(
        LocalBackupRestoreFailure.invalidBackup,
      );
    }

    final backup = validation.backup!;
    try {
      await _replaceArchiveWithBackup(backup);
      await reloadArchiveStores();
      recomputeArchiveSurfaces(backup.entries);

      LocalBackupAnalytics.restored(
        source: source,
        hasEntries: backup.hasEntries,
        schemaVersion: backup.schemaVersion,
      );

      return LocalBackupRestoreResult.success(
        entryCount: backup.entries.length,
        schemaVersion: backup.schemaVersion,
      );
    } catch (_, stackTrace) {
      LocalBackupAnalytics.restoreFailed(
        source: source,
        schemaVersion: archiveBackupVersion,
      );
      return const LocalBackupRestoreResult.failure(
        LocalBackupRestoreFailure.restoreFailed,
      );
    }
  }

  Future<void> _replaceArchiveWithBackup(LocalArchiveBackup backup) async {
    await controls.clearLocalArchive();
    await FirstProofTruthStore.clearBeforeRestore(prefs);

    await journal.replaceAll(backup.entries);

    for (final key in LocalArchiveBackupPrefsKeys.included) {
      final value = backup.prefs[key];
      if (value == null || value.isEmpty) {
        await prefs.writeJsonMap(key, {});
        continue;
      }
      if (key == LocalArchiveBackupPrefsKeys.patternNames) {
        await prefs.writeMap(key, value);
      } else {
        await prefs.writeJsonMap(key, value);
      }
    }
  }

  static Future<void> reloadArchiveStores() async {
    PatternNameStore.resetPersistedState();
    HelpedTrackingStore.invalidateAfterRestore();
    WhatChangedV2Store.invalidateAfterRestore();
    ArchiveExclusionStore.invalidateAfterRestore();
    EntryImportanceStore.invalidateAfterRestore();
    FirstProofTruthStore.invalidateAfterRestore();

    await PatternNameStore.ensureLoaded();
    await HelpedTrackingStore.ensureLoaded();
    await WhatChangedV2Store.ensureLoaded();
    await ArchiveExclusionStore.ensureLoaded();
    await EntryImportanceStore.ensureLoaded();
    await FirstProofTruthStore.ensureLoaded();
  }

  @visibleForTesting
  static void recomputeArchiveSurfaces(List<JournalEntry> entries) {
    ArchiveHistoryEngine.build(entries: entries);
    PatternDetailEngine.build(
      entries: entries,
    );
  }

  static Future<String?> _defaultPickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.bytes != null) {
      return utf8.decode(file.bytes!);
    }
    final path = file.path;
    if (path == null || path.isEmpty) return null;
    return File(path).readAsString();
  }
}