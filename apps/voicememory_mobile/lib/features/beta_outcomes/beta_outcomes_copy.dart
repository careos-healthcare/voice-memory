import '../beta_feedback/beta_feedback_models.dart';
import '../beta_invite/beta_invite_copy.dart';
import '../pro_interest/pro_interest_copy.dart';
import 'beta_outcomes_models.dart';

/// Copy for the local beta outcomes dashboard.
abstract final class BetaOutcomesCopy {
  BetaOutcomesCopy._();

  static const screenTitle = 'Beta outcomes';
  static const subtitle =
      'Local signals only. No private entries are shown or uploaded.';

  static const metricsSectionTitle = 'Local metrics';
  static const interpretationSectionTitle = 'Outcome interpretation';

  static const savedMomentsLabel = 'Saved moments';
  static const usableEvidenceLabel = 'Usable evidence moments';
  static const depthLevelLabel = 'Archive depth';
  static const watchThemesLabel = 'Watch themes';
  static const returnRitualLabel = 'Return ritual set';
  static const feedbackStatusLabel = 'Beta feedback status';
  static const optionalNoteLabel = 'Optional note present';
  static const testimonialCopiedLabel = 'Testimonial helper copied';
  static const shareProofReadyLabel = 'Share-safe proof ready';

  static const proInterestCapturedLabel = ProInterestCopy.betaOutcomesCapturedLabel;
  static const proInterestValueCountLabel =
      ProInterestCopy.betaOutcomesValueCountLabel;
  static const proInterestPricingLabel = ProInterestCopy.betaOutcomesPricingLabel;
  static const proInterestNotePresentLabel =
      ProInterestCopy.betaOutcomesNotePresentLabel;

  static const betaInviteCopiedLabel = BetaInviteCopy.betaOutcomesTotalLabel;
  static const betaInviteLastVariantLabel =
      BetaInviteCopy.betaOutcomesLastVariantLabel;
  static const betaInviteTaskCopiedLabel =
      BetaInviteCopy.betaOutcomesTaskCopiedLabel;

  static const firstWeekPathProgressLabel = 'First week path progress';

  static const openBetaInvitePackButton = BetaInviteCopy.openBetaInviteButton;

  static const yesLabel = 'Yes';
  static const noLabel = 'No';

  static const interpretationNotEnoughEvidence =
      'Not enough evidence yet. The next goal is getting to 3 saved moments.';
  static const interpretationReadyForFeedback = 'Ready for beta feedback.';
  static const interpretationEarlyValue = 'Early value signal present.';
  static const interpretationClarityRisk =
      'Clarity risk. Review first-session copy and sample archive path.';
  static const interpretationArchiveLoop = 'Archive loop is testable.';
  static const interpretationLongTerm =
      'Long-term archive value can be tested.';

  static const openBetaFeedbackButton = 'Open beta feedback';
  static const copySummaryButton = 'Copy safe beta summary';
  static const openSampleArchiveButton = 'Open Sample Archive';
  static const addMomentButton = 'Add a moment';

  static const summaryCopied = 'Safe beta summary copied';

  static const supportSectionTitle = 'Beta outcomes';
  static const supportSectionBody =
      'See local ArchiveMe validation signals from your archive and beta feedback. '
      'Nothing is uploaded.';
  static const openBetaOutcomesButton = 'Open beta outcomes';

  static const helpSectionTitle = 'Beta outcomes';
  static const helpSectionBody =
      'Reviewers can open Beta outcomes for local validation counts without '
      'seeing private entries.';

  static const feedbackNoResponse = 'no response';
  static const feedbackUseful = 'useful';
  static const feedbackNotYet = 'not yet';
  static const feedbackUnderstood = 'understood';
  static const feedbackConfused = 'confused';

  static String feedbackStatusFor(BetaFeedbackState state) {
    if (!state.hasResponse) return feedbackNoResponse;
    final parts = <String>[];
    switch (state.usefulness) {
      case BetaFeedbackUsefulness.useful:
        parts.add(feedbackUseful);
      case BetaFeedbackUsefulness.notYet:
        parts.add(feedbackNotYet);
      case null:
        break;
    }
    switch (state.clarity) {
      case BetaFeedbackClarity.understood:
        parts.add(feedbackUnderstood);
      case BetaFeedbackClarity.confused:
        parts.add(feedbackConfused);
      case null:
        break;
    }
    return parts.isEmpty ? feedbackNoResponse : parts.join(', ');
  }

  static String buildSafeSummary(BetaOutcomesSnapshot snapshot) {
    final depth = snapshot.depthLevelLabel.toLowerCase();
    return 'ArchiveMe beta summary: ${snapshot.savedMomentCount} saved moments, '
        '${snapshot.usableEvidenceCount} usable evidence moments, '
        'archive depth: $depth, '
        'beta feedback: ${snapshot.feedbackStatusLabel}, '
        'watch themes: ${snapshot.watchThemesCount}.';
  }

  static List<String> allVisibleCopy() => [
        screenTitle,
        subtitle,
        metricsSectionTitle,
        interpretationSectionTitle,
        savedMomentsLabel,
        usableEvidenceLabel,
        depthLevelLabel,
        watchThemesLabel,
        returnRitualLabel,
        feedbackStatusLabel,
        optionalNoteLabel,
        testimonialCopiedLabel,
        shareProofReadyLabel,
        proInterestCapturedLabel,
        proInterestValueCountLabel,
        proInterestPricingLabel,
        proInterestNotePresentLabel,
        betaInviteCopiedLabel,
        betaInviteLastVariantLabel,
        betaInviteTaskCopiedLabel,
        openBetaInvitePackButton,
        yesLabel,
        noLabel,
        interpretationNotEnoughEvidence,
        interpretationReadyForFeedback,
        interpretationEarlyValue,
        interpretationClarityRisk,
        interpretationArchiveLoop,
        interpretationLongTerm,
        openBetaFeedbackButton,
        copySummaryButton,
        openSampleArchiveButton,
        addMomentButton,
        summaryCopied,
        supportSectionTitle,
        supportSectionBody,
        openBetaOutcomesButton,
        helpSectionTitle,
        helpSectionBody,
        feedbackNoResponse,
        feedbackUseful,
        feedbackNotYet,
        feedbackUnderstood,
        feedbackConfused,
      ];
}
