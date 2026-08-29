import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/activation/archive_insight_feedback.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/security/caregiver_session_guard.dart';
import 'package:archiveme_mobile/security/privacy_claim_catalogue.dart';
import 'package:archiveme_mobile/security/user_content_safety.dart';
import 'package:archiveme_mobile/storage/app_storage_paths.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Result of a secure entry delete — includes whether local audio was removed.
class SecureDeleteEntryResult {
  const SecureDeleteEntryResult({
    required this.deleted,
    this.audioFileRemoved = false,
    this.audioPath,
  });

  final bool deleted;
  final bool audioFileRemoved;
  final String? audioPath;
}

/// User-owned export payload — sanitized plain text, no internal transport paths.
class ArchiveExportPayload {
  const ArchiveExportPayload({
    required this.entries,
    required this.exportedAt,
    this.insightCorrectionNotes = const [],
  });

  final List<Map<String, dynamic>> entries;
  final DateTime exportedAt;
  final List<Map<String, String>> insightCorrectionNotes;

  String toJson() => const JsonEncoder.withIndent('  ').convert({
    'app': 'ArchiveMe',
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'entryCount': entries.length,
    'insightCorrectionNotes': insightCorrectionNotes,
    'entries': entries,
  });
}

/// Removes orphaned temp recording files from the device temp directory.
abstract class TempRecordingCleanup {
  TempRecordingCleanup._();

  /// Unreferenced `vm_rec_*` files older than this are removed on startup.
  static const Duration staleOrphanMaxAge = Duration(hours: 1);

  static bool isTempRecordingPath(String path) {
    final name = path.split(Platform.pathSeparator).last;
    return name.startsWith('vm_rec_') &&
        (name.endsWith('.m4a') || name.endsWith('.wav'));
  }

  static Future<Directory?> _resolveTempDirectory(Directory? tempDir) async {
    if (tempDir != null) return tempDir;
    try {
      WidgetsFlutterBinding.ensureInitialized();
      return await AppStoragePaths.temporaryDirectory();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<void> purgeRetryRecordings({Directory? tempDir}) async {
    final temp = await _resolveTempDirectory(tempDir);
    if (temp == null || !temp.existsSync()) return;
    for (final entity in temp.listSync()) {
      if (entity is! File) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (name.startsWith('vm_rec_retry_')) {
        try {
          if (entity.existsSync()) await entity.delete();
        } on FileSystemException catch (e, stackTrace) {
          AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
          }
      }
    }
  }

  static Future<void> purgeTempRecordings({
    Directory? tempDir,
    Set<String> preservePaths = const {},
  }) async {
    final temp = await _resolveTempDirectory(tempDir);
    if (temp == null || !temp.existsSync()) return;
    for (final entity in temp.listSync()) {
      if (entity is! File) continue;
      if (!isTempRecordingPath(entity.path)) continue;
      if (preservePaths.contains(entity.path)) continue;
      try {
        if (entity.existsSync()) await entity.delete();
      } on FileSystemException catch (e, stackTrace) {
        AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
        }
    }
  }

  /// Paths still needed for offline draft retry or degraded voice capture.
  static Future<Set<String>> preservePathsForOfflineRetry(
    JournalStore journal,
  ) async {
    final entries = await journal.loadAll();
    final preserve = <String>{};
    for (final entry in entries) {
      final path = entry.localAudioPath?.trim();
      if (path == null || path.isEmpty || !isTempRecordingPath(path)) continue;
      if (VoiceCaptureQuality.isDegradedVoiceCapture(entry)) {
        preserve.add(path);
      }
    }
    return preserve;
  }

  /// Deletes temp audio after a successful save when transcript is usable.
  /// Offline / degraded drafts keep audio for retry or typed fallback.
  static Future<JournalEntry> releaseTempAudioIfSafe(
    JournalEntry entry,
    JournalStore journal, {
    String first25Source = 'temp_audio_released',
  }) async {
    if (VoiceCaptureQuality.isDegradedVoiceCapture(entry)) return entry;
    final path = entry.localAudioPath?.trim();
    if (path == null || path.isEmpty || !isTempRecordingPath(path)) {
      return entry;
    }

    await _deleteFileIfExists(path);
    final cleared = _entryWithoutLocalAudioPath(entry);
    await journal.save(cleared, first25Source: first25Source);
    return cleared;
  }

  /// Startup sweep: release transcribed temp audio, then purge stale orphans.
  static Future<void> purgeStaleOnStartup({
    required JournalStore journalStore,
    Directory? tempDir,
    Duration orphanMaxAge = staleOrphanMaxAge,
    DateTime Function()? clock,
  }) async {
    final now = clock ?? DateTime.now;
    final entries = await journalStore.loadAll();
    for (final entry in entries) {
      await releaseTempAudioIfSafe(
        entry,
        journalStore,
        first25Source: 'startup_temp_audio_released',
      );
    }

    final preserve = await preservePathsForOfflineRetry(journalStore);
    final temp = await _resolveTempDirectory(tempDir);
    if (temp == null || !temp.existsSync()) return;

    for (final entity in temp.listSync()) {
      if (entity is! File) continue;
      if (!isTempRecordingPath(entity.path)) continue;
      if (preserve.contains(entity.path)) continue;

      try {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name.startsWith('vm_rec_retry_')) {
          if (entity.existsSync()) await entity.delete();
          continue;
        }
        final age = now().difference(entity.statSync().modified);
        if (age >= orphanMaxAge && entity.existsSync()) {
          await entity.delete();
        }
      } on FileSystemException catch (e, stackTrace) {
        AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
        }
    }
  }

  static JournalEntry _entryWithoutLocalAudioPath(JournalEntry entry) =>
      entry.clearLocalAudioPath();

  static Future<bool> _deleteFileIfExists(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return false;
      await file.delete();
      return true;
    } on FileSystemException catch (_, stackTrace) {
      return false;
    }
  }
}

/// Secure delete, wipe, and export for private archive data.
class PrivateDataService {
  PrivateDataService({
    required JournalStore journalStore,
    this._prefs,
    Future<Directory> Function()? tempDirProvider,
  }) : _journal = journalStore,
       _tempDirProvider = tempDirProvider ?? AppStoragePaths.temporaryDirectory;

  final JournalStore _journal;
  final MobilePrefsStore? _prefs;
  final Future<Directory> Function() _tempDirProvider;

  static const wipeConfirmationPhrase =
      PrivacyClaimCatalogue.deleteArchiveConfirmationPhrase;

  Future<Directory?> _resolveTempDirectory() async {
    try {
      return await _tempDirProvider();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<SecureDeleteEntryResult> deleteEntrySecurely(String id) async {
    final entry = await _journal.getById(id);
    if (entry == null) {
      return const SecureDeleteEntryResult(deleted: false);
    }

    var audioRemoved = false;
    final audioPath = entry.localAudioPath?.trim();
    if (audioPath != null && audioPath.isNotEmpty) {
      audioRemoved = await _deleteFileIfExists(audioPath);
    }

    await _journal.delete(id);
    await TempRecordingCleanup.purgeRetryRecordings(
      tempDir: await _resolveTempDirectory(),
    );
    return SecureDeleteEntryResult(
      deleted: true,
      audioFileRemoved: audioRemoved,
      audioPath: audioPath,
    );
  }

  Future<void> wipeAllLocalArchive({required String confirmationPhrase}) async {
    if (confirmationPhrase.trim() != wipeConfirmationPhrase) {
      throw ArgumentError('Confirmation phrase did not match.');
    }
    await clearLocalArchiveData();
  }

  /// Destructive, device-wide wipe distinct from [wipeAllLocalArchive]/
  /// [clearLocalArchiveData]: deletes every account namespace directory
  /// under `accounts/` — including the guest namespace and every signed-in
  /// account that has ever used this device, not just whichever one is
  /// currently active.
  ///
  /// This is a `static` method rather than an instance method because it
  /// necessarily operates on namespaces this [PrivateDataService] (bound to
  /// one specific [JournalStore]) has no open handle to — it works directly
  /// against the filesystem instead of going through any `JournalStore`/
  /// `MobilePrefsStore` instance.
  static Future<int> wipeAllAccountsOnDevice({
    required String documentsBasePath,
    required String confirmationPhrase,
  }) async {
    if (confirmationPhrase.trim() != wipeConfirmationPhrase) {
      throw ArgumentError('Confirmation phrase did not match.');
    }
    final accountsDir = Directory('$documentsBasePath/accounts');
    if (!await accountsDir.exists()) return 0;
    var wipedCount = 0;
    for (final entity in accountsDir.listSync()) {
      if (entity is Directory) {
        await entity.delete(recursive: true);
        wipedCount++;
      }
    }
    return wipedCount;
  }

  Future<void> clearLocalArchiveData() async {
    await _performLocalArchiveWipe();
  }

  Future<void> _performLocalArchiveWipe() async {
    final entries = await _journal.loadAll();
    for (final entry in entries) {
      final path = entry.localAudioPath?.trim();
      if (path != null && path.isNotEmpty) {
        await _deleteFileIfExists(path);
      }
    }

    await _journal.clearAll();
    await TempRecordingCleanup.purgeTempRecordings(
      tempDir: await _resolveTempDirectory(),
    );
    await _clearArchiveCaches();
  }

  Future<ArchiveExportPayload> buildSanitizedExport() async {
    // Sanitizing removes transport paths, not content: this is still every
    // reflection in the archive, which no caregiver scope covers.
    await CaregiverSessionGuard.assertOwnerAccess(
      CaregiverSessionGuard.exportSanitizedArchive,
    );
    await ArchiveInsightFeedbackStore.ensureLoaded();
    final all = await _journal.loadAll();
    final entries = all.map(_sanitizedEntry).toList();
    return ArchiveExportPayload(
      entries: entries,
      exportedAt: DateTime.now().toUtc(),
      insightCorrectionNotes: ArchiveInsightFeedbackStore.exportCorrectionNotes(),
    );
  }

  Map<String, dynamic> _sanitizedEntry(JournalEntry entry) {
    return {
      'createdAt': entry.createdAt.toUtc().toIso8601String(),
      'transcript': UserContentSafety.sanitizePlainText(entry.transcript),
      'durationSeconds': entry.durationSeconds,
      'reflection': {
        // Absent rather than blank when no reading was taken.
        if (entry.reflection.mood.trim().isNotEmpty)
          'mood': entry.reflection.mood,
        if (entry.reflection.emotionalIntensity > 0)
          'emotionalIntensity': entry.reflection.emotionalIntensity,
        'recurringThemes': entry.reflection.recurringThemes,
        'exactLanguagePattern': UserContentSafety.sanitizePlainText(
          entry.reflection.exactLanguagePattern,
        ),
        'concreteObservation': UserContentSafety.sanitizePlainText(
          entry.reflection.concreteObservation,
        ),
        'repeatedSignal': UserContentSafety.sanitizePlainText(
          entry.reflection.repeatedSignal,
        ),
      },
    };
  }

  Future<void> _clearArchiveCaches() async {
    final prefs = _prefs;
    if (prefs == null) return;

    const cacheKeys = [
      'archiveCollections',
      'archivePacks',
      'archiveMonthlyReviews',
      'archiveMilestoneReviews',
      'archiveDeepDiveNarratives',
      'archiveHistorianReports',
      'archiveSynthesisMeta',
      'archiveThreads',
      'offline_sync_journey_v1',
      'archiveFacts',
      'archiveActionItems',
      'archiveInsightFeedbackRecords',
      'secure_archive_insight_correction_notes_v1',
      'secure_pattern_custom_names_v1',
      'archiveReviewRitual',
      'archive_workspace_hints_dismissed',
      'archiveDailyChangeState',
      'archiveWatchlistItems',
      'archiveReturnLastSeenSnapshot',
      'archiveChangeTimelineMetrics',
      'archiveActivationFunnel',
      'pattern_name_preferences_v1',
      'helped_tracking_records_v1',
      'what_changed_v2_records_v1',
      'archive_pattern_exclusions_v1',
    ];
    for (final key in cacheKeys) {
      await prefs.writeMap(key, {});
    }
  }

  Future<bool> _deleteFileIfExists(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return false;
      await file.delete();
      return true;
    } on FileSystemException catch (_, stackTrace) {
      return false;
    }
  }
}