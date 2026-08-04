import '../activation/first_three_session_gates.dart';
import 'private_archive_report_model.dart';
import 'weekly_archive_review_gates.dart';
import '../../models/journal_entry.dart';
import '../repeat_return_check/repeat_return_check_models.dart';

/// Visibility and export tier gates for the private archive report.
abstract final class PrivateArchiveReportGates {
  PrivateArchiveReportGates._();

  static const minEntryCount = 3;

  static bool shouldShow({
    required bool loaded,
    required int entryCount,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool viewingConfirmedRepeatOrTimeline,
    required PrivateArchiveReport? report,
  }) =>
      loaded &&
      isReady &&
      !isRecording &&
      !isPostSave &&
      entryCount >= minEntryCount &&
      viewingConfirmedRepeatOrTimeline &&
      report != null &&
      report.hasContent;

  static bool hasWeeklyEvidence({
    required int entryCount,
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) => WeeklyArchiveWeekReviewGates.hasEnoughEvidence(
    entryCount: entryCount,
    entries: entries,
    returnChecks: returnChecks,
  );

  static bool showFullExport({required bool isPro}) => true;

  static bool showPreviewNote({required bool isPro}) => false;

  static bool includeSectionInPreview({
    required int sectionIndex,
    required bool isPro,
    required int previewSectionCount,
  }) => true;

  static bool passesActivationGate(int entryCount) =>
      entryCount > FirstThreeSessionGates.minEntriesForUsefulArchive;
}
