import 'package:archiveme_mobile/features/early_archive/private_archive_report_model.dart';
import 'package:archiveme_mobile/features/private_report/private_report_builder.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds a private evidence report from existing proof engines only.
abstract final class PrivateArchiveReportEngine {
  PrivateArchiveReportEngine._();

  static PrivateArchiveReport? build({
    required List<JournalEntry> entries,
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool viewingConfirmedRepeatOrTimeline = false,
    bool isRecording = false,
    bool isPostSave = false,
  }) => PrivateReportBuilder.build(
    entries: entries,
    triggerCapturedMilestone: triggerCapturedMilestone,
    helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
    returnChecks: returnChecks,
    viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
    isRecording: isRecording,
    isPostSave: isPostSave,
  );
}