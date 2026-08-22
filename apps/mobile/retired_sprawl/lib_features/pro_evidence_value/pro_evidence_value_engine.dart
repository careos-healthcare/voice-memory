import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:archiveme_mobile/features/pattern_review_inbox/pattern_review_inbox_engine.dart';
import 'package:archiveme_mobile/features/pattern_review_inbox/pattern_review_inbox_model.dart';
import 'package:archiveme_mobile/features/pro_evidence_value/pro_evidence_value_copy.dart';
import 'package:archiveme_mobile/features/pro_evidence_value/pro_evidence_value_dismiss_store.dart';
import 'package:archiveme_mobile/features/pro_evidence_value/pro_evidence_value_model.dart';
import 'package:archiveme_mobile/features/pro_memory/pro_memory_boundary_engine.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Visibility and display for the Pro evidence value bridge — no billing changes.
abstract final class ProEvidenceValueEngine {
  ProEvidenceValueEngine._();

  static bool exportReportsLive = true;

  static ProEvidenceValueDisplay buildDisplay() {
    return ProEvidenceValueDisplay(
      title: ProEvidenceValueCopy.title,
      body: ProEvidenceValueCopy.body,
      cta: ProEvidenceValueCopy.cta,
      secondary: ProEvidenceValueCopy.secondary,
      chatGptDifferentiationLine:
          ProEvidenceValueCopy.chatGptDifferentiationLine,
      evidenceLine: ProEvidenceValueCopy.evidenceLine,
      comparesMomentsLine: ProEvidenceValueCopy.comparesMomentsLine,
      sheetTitle: ProEvidenceValueCopy.sheetTitle,
      freeSectionTitle: ProEvidenceValueCopy.freeSectionTitle,
      freeBullets: ProEvidenceValueCopy.freeBullets,
      proSectionTitle: ProEvidenceValueCopy.proSectionTitle,
      proBullets: ProEvidenceValueCopy.proBulletsForDisplay(
        exportReportsLive: exportReportsLive,
      ),
      sheetFooter: ProEvidenceValueCopy.sheetFooter,
      exportReportsLive: exportReportsLive,
    );
  }

  static ProEvidenceValueContext buildContext({
    required ProEvidenceValueSurface surface,
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
    bool currentRelevanceQuestionActive = false,
    bool firstProofPayoffVisible = false,
    bool privateReportPreviewVisible = false,
    bool weeklyReviewPreviewVisible = false,
  }) {
    return ProEvidenceValueContext(
      surface: surface,
      entryCount: entryCount,
      isPro: isPro,
      dismissed: dismissed,
      firstProofPayoffSeen:
          firstProofPayoffVisible || firstProofPayoffSeenForEntries(entries),
      hasConfirmedRepeatEvidence:
          EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
      privateReportPreviewVisible: privateReportPreviewVisible,
      weeklyReviewPreviewVisible: weeklyReviewPreviewVisible,
      isZeroEntryState: isZeroEntryState,
      isFirstRecordingState: isFirstRecordingState,
      isDegradedTranscriptState: isDegradedTranscriptState,
      isPostSaveDegradedState: isPostSaveDegradedState,
      firstProofTruthQuestionActive: firstProofTruthQuestionActive,
      whatChangedQuestionActive: whatChangedQuestionActive,
      currentRelevanceQuestionActive: currentRelevanceQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems(
        entries: entries,
        returnChecks: returnChecks,
      ),
      exportReportsLive: exportReportsLive,
    );
  }

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) {
    if (entries.isEmpty) return false;
    final inbox = PatternReviewInboxEngine.build(
      entries: entries,
      returnChecks: returnChecks,
    );
    for (final item in inbox.items) {
      switch (item.type) {
        case PatternReviewInboxItemType.firstProofTruth:
        case PatternReviewInboxItemType.whatChanged:
        case PatternReviewInboxItemType.helpedTracking:
          return true;
        case PatternReviewInboxItemType.quietSignal:
        case PatternReviewInboxItemType.patternCorrection:
        case PatternReviewInboxItemType.patternRename:
          continue;
      }
    }
    return false;
  }

  static bool firstProofPayoffSeenForEntries(List<JournalEntry> entries) =>
      FirstProofPayoffEngine.build(entries: entries) != null;

  static bool shouldShowCard(ProEvidenceValueContext context) {
    if (_isBlocked(context)) return false;
    return switch (context.surface) {
      ProEvidenceValueSurface.recordReady =>
        context.firstProofPayoffSeen || context.hasConfirmedRepeatEvidence,
      ProEvidenceValueSurface.recordPostSaveAfterPayoff =>
        context.firstProofPayoffSeen,
      ProEvidenceValueSurface.privateReportPreview =>
        context.privateReportPreviewVisible &&
            context.hasConfirmedRepeatEvidence,
      ProEvidenceValueSurface.archivePatterns =>
        context.hasConfirmedRepeatEvidence,
      ProEvidenceValueSurface.weeklyReviewPreview =>
        context.weeklyReviewPreviewVisible &&
            context.hasConfirmedRepeatEvidence,
    };
  }

  static bool _isBlocked(ProEvidenceValueContext context) {
    if (context.isPro) return true;
    if (context.dismissed) return true;
    if (context.entryCount <= 0 || context.isZeroEntryState) return true;
    if (context.isFirstRecordingState) return true;
    if (context.isDegradedTranscriptState) return true;
    if (context.isPostSaveDegradedState) return true;
    if (context.firstProofTruthQuestionActive) return true;
    if (context.whatChangedQuestionActive) return true;
    if (context.currentRelevanceQuestionActive) return true;
    if (context.patternReviewInboxHasActiveItems) return true;
    return false;
  }

  static Future<bool> resolveIsPro({bool? cachedIsPro}) =>
      ProMemoryBoundaryEngine.resolveIsPro(cachedIsPro: cachedIsPro);

  static Future<bool> isDismissed() async {
    await ProEvidenceValueDismissStore.ensureLoaded();
    return ProEvidenceValueDismissStore.isDismissed();
  }

  static Future<void> dismissForSession({DateTime? now}) =>
      ProEvidenceValueDismissStore.dismiss(now: now);
}