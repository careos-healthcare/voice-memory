import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';

/// Pure gates for capture recovery surfaces — no UI, no network.
abstract final class CaptureRecoveryGates {
  CaptureRecoveryGates._();

  static const minDaysSinceLastEntryForWelcomeBack = 3;

  static int daysSinceLastEntry({
    required List<JournalEntry> entries,
    DateTime? now,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty) return 0;
    final anchor = now ?? DateTime.now();
    final latest = eligible
        .map((entry) => entry.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final days = anchor.difference(latest).inDays;
    return days < 0 ? 0 : days;
  }

  static bool showReturnedAfterDelay({
    required int entryCount,
    required int daysSinceLastEntry,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
  }) =>
      entryCount >= 1 &&
      daysSinceLastEntry >= minDaysSinceLastEntryForWelcomeBack &&
      isReady &&
      !isRecording &&
      !isPostSave;
}
