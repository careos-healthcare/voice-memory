import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/journal_entry.dart';
import '../storage/app_storage_paths.dart';
import '../storage/journal_store.dart';
import '../storage/mobile_prefs_store.dart';
import 'user_content_safety.dart';

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
  const ArchiveExportPayload({required this.entries, required this.exportedAt});

  final List<Map<String, dynamic>> entries;
  final DateTime exportedAt;

  String toJson() => const JsonEncoder.withIndent('  ').convert({
    'app': 'ArchiveMe',
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'entryCount': entries.length,
    'entries': entries,
  });
}

/// Removes orphaned temp recording files from the device temp directory.
abstract class TempRecordingCleanup {
  TempRecordingCleanup._();

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
        } catch (_) {}
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
      final name = entity.path.split(Platform.pathSeparator).last;
      final isTempRecording =
          name.startsWith('vm_rec_') &&
          (name.endsWith('.m4a') || name.endsWith('.wav'));
      if (!isTempRecording) continue;
      if (preservePaths.contains(entity.path)) continue;
      try {
        if (entity.existsSync()) await entity.delete();
      } catch (_) {}
    }
  }
}

/// Secure delete, wipe, and export for private archive data.
class PrivateDataService {
  PrivateDataService({
    required JournalStore journalStore,
    MobilePrefsStore? prefs,
    Future<Directory> Function()? tempDirProvider,
  }) : _journal = journalStore,
       _prefs = prefs,
       _tempDirProvider = tempDirProvider ?? AppStoragePaths.temporaryDirectory;

  final JournalStore _journal;
  final MobilePrefsStore? _prefs;
  final Future<Directory> Function() _tempDirProvider;

  static const wipeConfirmationPhrase = 'DELETE MY ARCHIVE';

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
      tempDir: await _tempDirProvider(),
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
      tempDir: await _tempDirProvider(),
    );
    await _clearArchiveCaches();
  }

  Future<ArchiveExportPayload> buildSanitizedExport() async {
    final all = await _journal.loadAll();
    final entries = all.map(_sanitizedEntry).toList();
    return ArchiveExportPayload(
      entries: entries,
      exportedAt: DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> _sanitizedEntry(JournalEntry entry) {
    return {
      'createdAt': entry.createdAt.toUtc().toIso8601String(),
      'transcript': UserContentSafety.sanitizePlainText(entry.transcript),
      'durationSeconds': entry.durationSeconds,
      'reflection': {
        'mood': entry.reflection.mood,
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
      'archiveReviewRitual',
      'archive_workspace_hints_dismissed',
      'archiveDailyChangeState',
      'archiveWatchlistItems',
      'archiveReturnLastSeenSnapshot',
      'archiveChangeTimelineMetrics',
      'archiveActivationFunnel',
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
    } catch (_) {
      return false;
    }
  }
}
