import '../../models/journal_entry.dart';
import '../private_report/private_report_builder.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'private_archive_report_model.dart';

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
  }) =>
      PrivateReportBuilder.build(
        entries: entries,
        triggerCapturedMilestone: triggerCapturedMilestone,
        helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
        returnChecks: returnChecks,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
        isRecording: isRecording,
        isPostSave: isPostSave,
      );
}
