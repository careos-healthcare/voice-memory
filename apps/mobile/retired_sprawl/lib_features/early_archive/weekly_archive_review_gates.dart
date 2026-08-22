import 'package:archiveme_mobile/features/beta/archive_beta_mission_gates.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/early_archive/weekly_archive_review_engine.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_trend.dart';
import 'package:archiveme_mobile/features/voice_capture/record_cta_policy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Visibility gates for the compact weekly archive review card.
abstract final class WeeklyArchiveWeekReviewGates {
  WeeklyArchiveWeekReviewGates._();

  static const minEntryCountForEarlyActivation = 4;

  static bool hasEnoughEvidence({
    required int entryCount,
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) {
    if (entryCount >=
        WeeklyArchiveWeekReviewEngine.minEntriesForFiveEntryGate) {
      return true;
    }
    return EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries) &&
        RepeatReturnCheckTrendEngine.hasAnsweredCheck(returnChecks);
  }

  static bool shouldShow({
    required bool loaded,
    required int entryCount,
    required bool isReady,
    required bool isRecording,
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) =>
      loaded &&
      isReady &&
      !isRecording &&
      entryCount >= minEntryCountForEarlyActivation &&
      hasEnoughEvidence(
        entryCount: entryCount,
        entries: entries,
        returnChecks: returnChecks,
      );

  static bool showRecordCta({
    required RecordCtaPolicyResolution policy,
    required bool hideCardRecordButtons,
    required bool promoteMicCaptureActions,
  }) => !ArchiveBetaMissionGates.capturePrimaryCtaVisible(
    policy: policy,
    hideCardRecordButtons: hideCardRecordButtons,
    promoteMicCaptureActions: promoteMicCaptureActions,
  );
}