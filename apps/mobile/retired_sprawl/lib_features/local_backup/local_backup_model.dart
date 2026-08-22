import 'package:archiveme_mobile/models/journal_entry.dart';

/// Current local archive backup schema version.
const archiveBackupVersion = 1;

/// Prefs keys included in a local archive backup.
abstract final class LocalArchiveBackupPrefsKeys {
  LocalArchiveBackupPrefsKeys._();

  static const patternNames = 'pattern_name_preferences_v1';
  static const helpedTracking = 'helped_tracking_records_v1';
  static const whatChanged = 'what_changed_v2_records_v1';
  static const firstProofTruth = 'firstProofTruthAnswered_v1';
  static const archiveExclusions = 'archive_pattern_exclusions_v1';
  static const entryImportance = 'entry_importance_markers_v1';

  static const List<String> included = [
    patternNames,
    helpedTracking,
    whatChanged,
    firstProofTruth,
    archiveExclusions,
    entryImportance,
  ];

  /// Prefs keys that must never appear in a backup file.
  static const excluded = [
    'archiveBetaFeedback',
    'beta_activation_summary_counts_v1',
    'beta_activation_loop_counts_v1',
    'archiveActivationFunnel',
    'entitlements.json',
  ];
}

/// Parsed, validated local archive backup payload.
class LocalArchiveBackup {
  const LocalArchiveBackup({
    required this.schemaVersion,
    required this.exportedAt,
    required this.entries,
    required this.prefs,
  });

  final int schemaVersion;
  final DateTime exportedAt;
  final List<JournalEntry> entries;
  final Map<String, Map<String, dynamic>> prefs;

  bool get hasEntries => entries.isNotEmpty;
}

enum LocalArchiveBackupValidationFailure {
  notMap,
  wrongVersion,
  invalidJournal,
  invalidPrefs,
}

class LocalArchiveBackupValidationResult {
  const LocalArchiveBackupValidationResult.valid(this.backup) : failure = null;

  const LocalArchiveBackupValidationResult.invalid(this.failure)
    : backup = null;

  final LocalArchiveBackup? backup;
  final LocalArchiveBackupValidationFailure? failure;

  bool get isValid => backup != null;
}