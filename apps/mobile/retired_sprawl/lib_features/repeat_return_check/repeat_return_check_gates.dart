import 'package:archiveme_mobile/features/activation/first_three_session_gates.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_trend.dart';
import 'package:archiveme_mobile/features/retention/second_session_signal_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// When to offer the repeat intensity check after save.
abstract final class RepeatReturnCheckGates {
  RepeatReturnCheckGates._();

  static const _signalEngine = SecondSessionSignalEngine();

  /// True when the archive already has a confirmed repeat and this save extends it.
  static bool hasRelatedRepeatSave(List<JournalEntry> entriesAfterSave) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entriesAfterSave);
    if (eligible.length <= FirstThreeSessionGates.minEntriesForUsefulArchive) {
      return false;
    }

    final foundation = eligible.sublist(0, 3);
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatAcrossThree(foundation)) {
      return false;
    }

    if (eligible.length < 2) return false;
    return _signalEngine.hasGroundedRepeatMatch(
      eligible.sublist(eligible.length - 2),
    );
  }

  static bool shouldOfferForEntry({
    required List<JournalEntry> entriesAfterSave,
    required RepeatReturnCheckRecord? existing,
  }) {
    if (!hasRelatedRepeatSave(entriesAfterSave)) return false;
    if (existing != null && existing.completed) return false;
    return true;
  }

  /// Change-over-time proof on Record / Patterns ready surfaces.
  static bool shouldShowChangeProofCard({
    required int entryCount,
    required bool viewingConfirmedRepeat,
    required bool isRecording,
    required bool isPostSave,
    required List<RepeatReturnCheckRecord> records,
  }) {
    if (entryCount <= FirstThreeSessionGates.minEntriesForUsefulArchive) {
      return false;
    }
    if (!viewingConfirmedRepeat) return false;
    if (isRecording) return false;
    if (isPostSave) return false;
    return RepeatReturnCheckTrendEngine.hasAnsweredCheck(records);
  }
}