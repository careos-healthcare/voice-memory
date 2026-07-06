import '../../models/journal_entry.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../pro_evidence_value/pro_evidence_value_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'pro_lock_moment_copy.dart';
import 'pro_lock_moment_model.dart';

/// Visibility for the Pro lock moment — post-first-proof only, no billing changes.
abstract final class ProLockMomentEngine {
  ProLockMomentEngine._();

  static const recordPostSaveSource = 'record_post_save_first_proof';

  static ProLockMomentDisplay buildDisplay() {
    return ProLockMomentDisplay(
      title: ProLockMomentCopy.title,
      body: ProLockMomentCopy.body,
      paidReason: ProLockMomentCopy.paidReason,
      chatDifferentiation: ProLockMomentCopy.chatDifferentiation,
      cta: ProLockMomentCopy.cta,
      secondary: ProLockMomentCopy.secondary,
      sheetTitle: ProLockMomentCopy.sheetTitle,
    );
  }

  static ProLockMomentContext buildContext({
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
    bool firstProofPayoffVisible = false,
    bool proEvidenceValueVisible = false,
  }) {
    final hasFirstProof = firstProofPayoffVisible ||
        ProEvidenceValueEngine.firstProofPayoffSeenForEntries(entries);
    return ProLockMomentContext(
      entryCount: entryCount,
      isPro: isPro,
      dismissed: dismissed,
      hasFirstProof: hasFirstProof,
      hasConfirmedRepeat:
          EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
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
      proEvidenceValueVisible: proEvidenceValueVisible,
    );
  }

  static bool shouldShowCard(ProLockMomentContext context) {
    if (_isBlocked(context)) return false;
    return context.hasFirstProof;
  }

  static bool _isBlocked(ProLockMomentContext context) {
    if (context.isPro) return true;
    if (context.dismissed) return true;
    if (context.proEvidenceValueVisible) return true;
    if (context.entryCount <= 0 || context.isZeroEntryState) return true;
    if (context.isFirstRecordingState) return true;
    if (context.isDegradedTranscriptState) return true;
    if (context.isPostSaveDegradedState) return true;
    if (context.firstProofTruthQuestionActive) return true;
    if (context.whatChangedQuestionActive) return true;
    if (context.patternReviewInboxHasActiveItems) return true;
    return false;
  }
}
