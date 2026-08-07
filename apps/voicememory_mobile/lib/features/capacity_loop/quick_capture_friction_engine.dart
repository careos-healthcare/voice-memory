import '../../models/journal_entry.dart';
import '../demo/sample_archive_mode.dart';
import 'low_effort_yes_capture_engine.dart';
import 'quick_capture_friction_copy.dart';
import 'quick_capture_friction_models.dart';

/// Builds quick capture friction visibility — local flags only.
class QuickCaptureFrictionEngine {
  const QuickCaptureFrictionEngine();

  QuickCaptureFrictionResult build(QuickCaptureFrictionInput input) {
    if (!showFrictionCheck(input)) {
      return QuickCaptureFrictionResult.hidden;
    }

    return QuickCaptureFrictionResult(
      showCard: true,
      title: QuickCaptureFrictionCopy.title,
      body: QuickCaptureFrictionCopy.body,
      primaryCtaLabel: QuickCaptureFrictionCopy.saveAnswerCta,
      secondaryCtaLabel: QuickCaptureFrictionCopy.skipCta,
      responseIds: List<String>.from(QuickCaptureFrictionResponseIds.all),
      relatedEntryId: input.record?.relatedEntryId ?? '',
    );
  }

  QuickCaptureFrictionResult buildAfterQuickSave({
    required String relatedEntryId,
    required bool capacityWedgeActive,
    bool sampleMode = false,
    bool screenshotMode = false,
  }) {
    if (!capacityWedgeActive || sampleMode || screenshotMode) {
      return QuickCaptureFrictionResult.hidden;
    }
    return QuickCaptureFrictionResult(
      showCard: true,
      title: QuickCaptureFrictionCopy.title,
      body: QuickCaptureFrictionCopy.body,
      primaryCtaLabel: QuickCaptureFrictionCopy.saveAnswerCta,
      secondaryCtaLabel: QuickCaptureFrictionCopy.skipCta,
      responseIds: List<String>.from(QuickCaptureFrictionResponseIds.all),
      relatedEntryId: relatedEntryId,
    );
  }

  static bool showFrictionCheck(QuickCaptureFrictionInput input) {
    if (!input.capacityWedgeActive ||
        input.sampleMode ||
        input.screenshotMode) {
      return false;
    }
    if (input.showAfterQuickSave && input.hasQuickCaptureEntry) {
      return true;
    }
    return false;
  }

  static bool hasQuickCaptureEntry(List<JournalEntry> entries) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    if (entries.isNotEmpty && realEntries.isEmpty) return false;
    return realEntries.any(LowEffortYesCaptureEngine.isQuickCaptureEntry);
  }

  static String dashboardFrictionLabel(QuickCaptureFrictionRecord? record) =>
      QuickCaptureFrictionCopy.dashboardValueForRecord(record);
}
