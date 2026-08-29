import 'package:archiveme_mobile/features/activation/first_three_session_gates.dart';
import 'package:archiveme_mobile/features/early_archive/private_archive_report_model.dart';
import 'package:archiveme_mobile/features/early_archive/weekly_archive_review_gates.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

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

  // Private recap export is free forever (launch product contract, capability
  // "Export and deletion") — never gated behind Pro. These stay parameterized
  // on [isPro] so callers are unchanged, but the export is always complete.
  static bool showFullExport({required bool isPro}) => true;

  static bool showPreviewNote({required bool isPro}) => false;

  static bool includeSectionInPreview({
    required int sectionIndex,
    required bool isPro,
    int previewSectionCount = 1,
  }) => true;

  static bool passesActivationGate(int entryCount) =>
      entryCount > FirstThreeSessionGates.minEntriesForUsefulArchive;
}