import '../../models/journal_entry.dart';
import '../beta/archive_beta_mission_gate.dart';
import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../beta_proof_feedback/beta_proof_feedback_store.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../first_proof_payoff/first_proof_payoff_engine.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import '../pro_bridge_visibility/pro_bridge_timing_loosen_engine.dart';
import 'beta_invite_copy.dart';
import 'beta_invite_model.dart';
import 'beta_invite_models.dart';
import 'beta_invite_store.dart';

/// Deterministic beta invite summaries — counts only.
class BetaInviteEngine {
  const BetaInviteEngine();

  BetaInviteOutcomesSummary outcomesSummary(BetaInviteCopyStats stats) {
    final lastVariant = stats.lastVariantId == null
        ? BetaInviteCopy.betaOutcomesNoneLabel
        : BetaInviteCopy.variantTitle(stats.lastVariantId!);
    return BetaInviteOutcomesSummary(
      totalCopiedCount: stats.totalCopiedCount,
      lastVariantLabel: lastVariant,
      testerTaskCopied: stats.testerTaskCopied,
    );
  }
}

/// Beta invite loop card visibility — generic invite only, no billing changes.
abstract final class BetaInviteLoopEngine {
  BetaInviteLoopEngine._();

  static BetaInviteLoopContext buildContext({
    required BetaInviteLoopSurface surface,
    required String source,
    required int entryCount,
    required List<JournalEntry> entries,
    bool? betaMissionEnabled,
    bool dismissed = false,
    bool beliefSurfaceVisible = false,
    List<String> beliefEvidencePhrases = const [],
    bool isRecording = false,
    bool isDegradedTranscriptState = false,
    bool isPostSaveDegradedState = false,
    bool whatChangedQuestionActive = false,
    bool patternReviewInboxHasActiveItems = false,
  }) {
    final hasFirstProof = FirstProofPayoffEngine.build(entries: entries) != null ||
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
    final trigger = _resolveTrigger(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      source: source,
      beliefEvidencePhrases: beliefEvidencePhrases,
    );

    return BetaInviteLoopContext(
      surface: surface,
      source: source,
      entryCount: entryCount,
      betaMissionEnabled: betaMissionEnabled ?? ArchiveBetaMissionGate.isEnabled,
      dismissed: dismissed || BetaInviteLoopDismissStore.isDismissed(),
      hasFirstProof: hasFirstProof,
      trigger: trigger,
      isRecording: isRecording,
      isDegradedTranscriptState: isDegradedTranscriptState,
      isPostSaveDegradedState: isPostSaveDegradedState,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
    );
  }

  static BetaInviteLoopResult build({
    required BetaInviteLoopContext context,
  }) {
    final shouldShow = shouldShowCard(context);
    return BetaInviteLoopResult(
      shouldShow: shouldShow,
      title: BetaInviteCopy.loopCardTitle,
      body: BetaInviteCopy.loopCardBody,
      cta: BetaInviteCopy.loopCta,
      secondary: BetaInviteCopy.loopSecondary,
      inviteText: BetaInviteCopy.loopInviteText,
      source: context.source,
      surface: context.surface,
      entryCount: context.entryCount,
      trigger: context.trigger,
    );
  }

  static bool shouldShowCard(BetaInviteLoopContext context) {
    if (!context.betaMissionEnabled) return false;
    if (context.dismissed) return false;
    if (context.entryCount <= 0) return false;
    if (!context.hasFirstProof) return false;
    if (context.isRecording) return false;
    if (context.isDegradedTranscriptState) return false;
    if (context.isPostSaveDegradedState) return false;
    if (context.whatChangedQuestionActive) return false;
    if (context.patternReviewInboxHasActiveItems) return false;
    if (context.trigger == null) return false;
    return true;
  }

  static BetaInviteLoopTrigger? _resolveTrigger({
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
    required String source,
    List<String> beliefEvidencePhrases = const [],
  }) {
    if (_hasUsefulFeedbackToday()) {
      return BetaInviteLoopTrigger.usefulFeedback;
    }
    if (_hasStrongProof(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      source: source,
      beliefEvidencePhrases: beliefEvidencePhrases,
    )) {
      return BetaInviteLoopTrigger.strongProof;
    }
    return null;
  }

  static bool _hasUsefulFeedbackToday() {
    for (final surface in BetaProofFeedbackSurface.values) {
      if (!BetaProofFeedbackStore.isAnsweredToday(surface)) continue;
      final record = BetaProofFeedbackStore.recordFor(surface);
      if (record.feedbackType == BetaProofFeedbackType.useful) {
        return true;
      }
    }
    return false;
  }

  static bool _hasStrongProof({
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
    required String source,
    List<String> beliefEvidencePhrases = const [],
  }) {
    final signals = ProBridgeTimingLoosenEngine.resolveSignals(
      entries: entries,
      source: source,
      beliefSurfaceVisible: beliefSurfaceVisible,
      beliefEvidencePhrases: beliefEvidencePhrases,
    );
    if (signals.confidenceLevel == ProofConfidenceLevel.strong) {
      return true;
    }
    return signals.hasSolidStrongPatternWithSafeAnchors;
  }

  static bool isDismissed() => BetaInviteLoopDismissStore.isDismissed();

  static Future<void> dismissForSession({DateTime? now}) =>
      BetaInviteLoopDismissStore.dismiss(now: now);
}
