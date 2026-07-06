import 'package:flutter/material.dart';

import '../../models/journal_entry.dart';
import '../early_archive/private_archive_report_model.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import '../../widgets/private_report/private_report_sheet.dart';
import 'private_report_analytics.dart';
import 'private_report_builder.dart';
import 'private_report_copy.dart';
import 'private_report_model.dart';

/// Builds and presents the shareable private report.
abstract final class PrivateReportEngine {
  PrivateReportEngine._();

  static PrivateReportBuildResult? build({
    required List<JournalEntry> entries,
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool viewingConfirmedRepeatOrTimeline = false,
    bool isRecording = false,
    bool isPostSave = false,
  }) {
    final report = PrivateReportBuilder.build(
      entries: entries,
      triggerCapturedMilestone: triggerCapturedMilestone,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      returnChecks: returnChecks,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      isRecording: isRecording,
      isPostSave: isPostSave,
    );
    if (report == null) return null;

    return PrivateReportBuildResult(
      report: report,
      hasChange: _sectionHasEvidence(
        report,
        PrivateReportCopy.whatChangedHeading,
      ),
      hasHelped: _sectionHasEvidence(
        report,
        PrivateReportCopy.whatHelpedHeading,
      ),
    );
  }

  static Future<void> showSheet(
    BuildContext context, {
    required List<JournalEntry> entries,
    required String source,
    required bool isPro,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool viewingConfirmedRepeatOrTimeline = true,
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    bool isRecording = false,
    bool isPostSave = false,
  }) async {
    final result = build(
      entries: entries,
      returnChecks: returnChecks,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      triggerCapturedMilestone: triggerCapturedMilestone,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      isRecording: isRecording,
      isPostSave: isPostSave,
    );
    if (!context.mounted) return;
    if (result == null || !result.report.hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(PrivateReportCopy.insufficientEvidence)),
      );
      return;
    }

    await PrivateReportSheet.show(
      context,
      report: result.report,
      entryCount: entries.length,
      source: source,
      isPro: isPro,
      hasChange: result.hasChange,
      hasHelped: result.hasHelped,
    );
  }

  static bool _sectionHasEvidence(
    PrivateArchiveReport report,
    String heading,
  ) {
    for (final section in report.sections) {
      if (section.heading == heading) return section.hasEvidence;
    }
    return false;
  }
}
