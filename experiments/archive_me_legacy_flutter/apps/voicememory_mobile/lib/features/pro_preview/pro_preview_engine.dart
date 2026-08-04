import '../../models/journal_entry.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../first_proof_payoff/first_proof_payoff_engine.dart';
import '../pro_evidence_value/pro_evidence_value_dismiss_store.dart';
import '../pro_evidence_value/pro_evidence_value_engine.dart';
import 'pro_preview_copy.dart';
import 'pro_preview_model.dart';

/// Pro preview card visibility — generic rows only, no billing changes.
abstract final class ProPreviewEngine {
  ProPreviewEngine._();

  static ProPreviewContext buildContext({
    required ProPreviewSurface surface,
    required String source,
    required int entryCount,
    required bool isPro,
    required bool dismissed,
    required List<JournalEntry> entries,
    bool hasTimelineProofVisible = false,
    bool firstProofPayoffVisible = false,
    bool isZeroEntryState = false,
    bool isFirstRecordingState = false,
    bool isDegradedTranscriptState = false,
    bool isPostSaveDegradedState = false,
    bool firstProofTruthQuestionActive = false,
    bool whatChangedQuestionActive = false,
    bool patternReviewInboxHasActiveItems = false,
  }) {
    final firstProofPayoffSeen =
        firstProofPayoffVisible ||
        FirstProofPayoffEngine.build(entries: entries) != null;
    final hasFirstProof =
        firstProofPayoffSeen ||
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);

    return ProPreviewContext(
      surface: surface,
      source: source,
      entryCount: entryCount,
      isPro: isPro,
      dismissed: dismissed,
      hasFirstProof: hasFirstProof,
      hasTimelineProofVisible: hasTimelineProofVisible,
      firstProofPayoffSeen: firstProofPayoffSeen,
      isZeroEntryState: isZeroEntryState,
      isFirstRecordingState: isFirstRecordingState,
      isDegradedTranscriptState: isDegradedTranscriptState,
      isPostSaveDegradedState: isPostSaveDegradedState,
      firstProofTruthQuestionActive: firstProofTruthQuestionActive,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
    );
  }

  static ProPreviewResult build({required ProPreviewContext context}) {
    final shouldShow = shouldShowCard(context);
    return ProPreviewResult(
      shouldShow: shouldShow,
      title: ProPreviewCopy.title,
      body: ProPreviewCopy.body,
      previewRows: ProPreviewCopy.previewRows(),
      cta: ProPreviewCopy.cta,
      secondary: ProPreviewCopy.secondary,
      source: context.source,
      surface: context.surface,
      entryCount: context.entryCount,
      hasTimelineProof: context.hasTimelineProofVisible,
      hasFirstProof: context.hasFirstProof,
    );
  }

  static bool shouldShowCard(ProPreviewContext context) {
    if (_isBlocked(context)) return false;
    if (context.hasTimelineProofVisible) return true;
    if (context.firstProofPayoffSeen) return true;
    return context.hasFirstProof;
  }

  static bool _isBlocked(ProPreviewContext context) {
    if (context.isPro) return true;
    if (context.dismissed) return true;
    if (context.entryCount <= 0 || context.isZeroEntryState) return true;
    if (context.isFirstRecordingState) return true;
    if (context.isDegradedTranscriptState) return true;
    if (context.isPostSaveDegradedState) return true;
    if (context.firstProofTruthQuestionActive) return true;
    if (context.whatChangedQuestionActive) return true;
    if (context.patternReviewInboxHasActiveItems) return true;
    if (!context.hasFirstProof &&
        !context.hasTimelineProofVisible &&
        !context.firstProofPayoffSeen) {
      return true;
    }
    return false;
  }

  static bool isDismissed() => ProEvidenceValueDismissStore.isDismissed();

  static Future<void> dismissForSession({DateTime? now}) =>
      ProEvidenceValueDismissStore.dismiss(now: now);

  static bool firstProofPayoffSeenForEntries(List<JournalEntry> entries) =>
      ProEvidenceValueEngine.firstProofPayoffSeenForEntries(entries);
}
