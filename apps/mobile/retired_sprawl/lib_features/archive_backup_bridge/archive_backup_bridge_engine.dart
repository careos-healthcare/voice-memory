import 'package:archiveme_mobile/features/archive_backup_bridge/archive_backup_bridge_copy.dart';
import 'package:archiveme_mobile/features/archive_backup_bridge/archive_backup_bridge_model.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/monthly_private_report/monthly_private_report_engine.dart';
import 'package:archiveme_mobile/features/pro_evidence_value/pro_evidence_value_engine.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Eligibility and display for the archive preservation bridge.
abstract final class ArchiveBackupBridgeEngine {
  ArchiveBackupBridgeEngine._();

  static ArchiveBackupBridgeDisplay buildDisplay() {
    return const ArchiveBackupBridgeDisplay(
      title: ArchiveBackupBridgeCopy.cardTitle,
      body: ArchiveBackupBridgeCopy.cardBody,
      plannedProAreas: ArchiveBackupBridgeCopy.plannedProAreas,
      deviceBackupToday: ArchiveBackupBridgeCopy.deviceBackupToday,
      proPreservation: ArchiveBackupBridgeCopy.proPreservation,
      cta: ArchiveBackupBridgeCopy.cta,
      secondary: ArchiveBackupBridgeCopy.secondary,
      sheetTitle: ArchiveBackupBridgeCopy.sheetTitle,
      sheetIntro: ArchiveBackupBridgeCopy.sheetIntro,
      sheetLocalBackupLine: ArchiveBackupBridgeCopy.sheetLocalBackupLine,
      sheetSeeProCta: ArchiveBackupBridgeCopy.sheetSeeProCta,
    );
  }

  static bool hasReportPreview({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool viewingConfirmedRepeatOrTimeline = true,
  }) {
    return MonthlyPrivateReportEngine.build(
          entries: entries,
          returnChecks: returnChecks,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
        ) !=
        null;
  }

  static ArchiveBackupBridgeContext buildContext({
    required ArchiveBackupBridgeSurface surface,
    required int entryCount,
    required bool isPro,
    required bool dismissed,
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool isZeroEntryState = false,
    bool isFirstRecordingState = false,
    bool isDegradedTranscriptState = false,
    bool isPostSaveDegradedState = false,
    bool firstProofTruthQuestionActive = false,
    bool whatChangedQuestionActive = false,
    bool viewingConfirmedRepeatOrTimeline = true,
    bool? hasReportPreview,
    bool? hasSeenProof,
  }) {
    final resolvedHasSeenProof =
        hasSeenProof ??
        ProEvidenceValueEngine.firstProofPayoffSeenForEntries(entries);
    return ArchiveBackupBridgeContext(
      surface: surface,
      entryCount: entryCount,
      isPro: isPro,
      dismissed: dismissed,
      hasConfirmedRepeat: EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
        entries,
      ),
      hasReportPreview:
          hasReportPreview ??
          ArchiveBackupBridgeEngine.hasReportPreview(
            entries: entries,
            returnChecks: returnChecks,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
          ),
      hasSeenProof: resolvedHasSeenProof,
      isZeroEntryState: isZeroEntryState,
      isFirstRecordingState: isFirstRecordingState,
      isDegradedTranscriptState: isDegradedTranscriptState,
      isPostSaveDegradedState: isPostSaveDegradedState,
      firstProofTruthQuestionActive: firstProofTruthQuestionActive,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems:
          ProEvidenceValueEngine.patternReviewInboxHasActiveItems(
            entries: entries,
            returnChecks: returnChecks,
          ),
    );
  }

  static bool shouldShowCard(ArchiveBackupBridgeContext context) {
    if (_isBlocked(context)) return false;
    if (context.entryCount <= 1) return false;
    if (!context.hasArchiveValue) return false;
    return true;
  }

  static bool showProCta(ArchiveBackupBridgeContext context) => !context.isPro;

  static bool _isBlocked(ArchiveBackupBridgeContext context) {
    if (context.dismissed) return true;
    if (context.entryCount <= 0 || context.isZeroEntryState) return true;
    if (context.isFirstRecordingState) return true;
    if (context.isDegradedTranscriptState) return true;
    if (context.isPostSaveDegradedState) return true;
    if (context.firstProofTruthQuestionActive) return true;
    if (context.whatChangedQuestionActive) return true;
    if (context.patternReviewInboxHasActiveItems) return true;
    if (context.isPro &&
        context.surface == ArchiveBackupBridgeSurface.archivePatterns) {
      return true;
    }
    return false;
  }
}