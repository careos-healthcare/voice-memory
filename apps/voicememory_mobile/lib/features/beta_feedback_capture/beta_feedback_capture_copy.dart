import 'beta_feedback_capture_model.dart';

/// Generic beta feedback copy — no journal text, no private evidence.
abstract final class BetaFeedbackCaptureCopy {
  BetaFeedbackCaptureCopy._();

  static const dismissCta = 'Not today';

  static String titleFor(BetaFeedbackCaptureMoment moment) => switch (moment) {
    BetaFeedbackCaptureMoment.afterFirstSave => 'Was it clear what to do next?',
    BetaFeedbackCaptureMoment.afterThirdSave =>
      'Do you expect ArchiveMe to show something useful now?',
    BetaFeedbackCaptureMoment.afterTimelineProof => 'Did this proof feel real?',
    BetaFeedbackCaptureMoment.afterProPreview =>
      'Does Pro sound worth keeping?',
    BetaFeedbackCaptureMoment.afterPaywallSeenNoCta => 'What stopped you here?',
    BetaFeedbackCaptureMoment.afterPaywallCtaNoPurchase =>
      'What stopped the purchase?',
  };

  static String? followUpPlaceholderFor(BetaFeedbackCaptureMoment moment) =>
      switch (moment) {
        BetaFeedbackCaptureMoment.afterFirstSave => 'What was unclear?',
        BetaFeedbackCaptureMoment.afterProPreview =>
          'What would make it worth it?',
        _ => null,
      };

  static List<BetaFeedbackCaptureOption> optionsFor(
    BetaFeedbackCaptureMoment moment,
  ) => switch (moment) {
    BetaFeedbackCaptureMoment.afterFirstSave => const [
      BetaFeedbackCaptureOption(id: 'yes', label: 'Yes'),
      BetaFeedbackCaptureOption(id: 'somewhat', label: 'Somewhat'),
      BetaFeedbackCaptureOption(id: 'no', label: 'No'),
    ],
    BetaFeedbackCaptureMoment.afterThirdSave => const [
      BetaFeedbackCaptureOption(id: 'yes', label: 'Yes'),
      BetaFeedbackCaptureOption(id: 'maybe', label: 'Maybe'),
      BetaFeedbackCaptureOption(id: 'no', label: 'No'),
    ],
    BetaFeedbackCaptureMoment.afterTimelineProof => const [
      BetaFeedbackCaptureOption(id: 'useful', label: 'Useful'),
      BetaFeedbackCaptureOption(id: 'too_vague', label: 'Too vague'),
      BetaFeedbackCaptureOption(id: 'already_knew', label: 'Already knew this'),
      BetaFeedbackCaptureOption(id: 'not_relevant', label: 'Not relevant'),
    ],
    BetaFeedbackCaptureMoment.afterProPreview => const [
      BetaFeedbackCaptureOption(id: 'yes', label: 'Yes'),
      BetaFeedbackCaptureOption(id: 'maybe', label: 'Maybe'),
      BetaFeedbackCaptureOption(id: 'no', label: 'No'),
    ],
    BetaFeedbackCaptureMoment.afterPaywallSeenNoCta => const [
      BetaFeedbackCaptureOption(
        id: 'not_enough_value',
        label: 'Not enough value',
      ),
      BetaFeedbackCaptureOption(id: 'too_early', label: 'Too early'),
      BetaFeedbackCaptureOption(id: 'price_concern', label: 'Price concern'),
      BetaFeedbackCaptureOption(
        id: 'privacy_concern',
        label: 'Privacy concern',
      ),
      BetaFeedbackCaptureOption(id: 'just_looking', label: 'Just looking'),
    ],
    BetaFeedbackCaptureMoment.afterPaywallCtaNoPurchase => const [
      BetaFeedbackCaptureOption(id: 'price', label: 'Price'),
      BetaFeedbackCaptureOption(id: 'trust', label: 'Trust'),
      BetaFeedbackCaptureOption(id: 'payment_issue', label: 'Payment issue'),
      BetaFeedbackCaptureOption(
        id: 'need_more_proof',
        label: 'Need more proof',
      ),
      BetaFeedbackCaptureOption(id: 'other', label: 'Other'),
    ],
  };

  static String labelForAnswerId(
    BetaFeedbackCaptureMoment moment,
    String answerId,
  ) {
    for (final option in optionsFor(moment)) {
      if (option.id == answerId) return option.label;
    }
    return answerId;
  }

  static String unresolvedRevenueQuestion({
    required BetaFeedbackCaptureMoment? moment,
  }) {
    if (moment == null) return 'No open revenue breakpoint';
    return titleFor(moment);
  }

  static String panelLatestMomentLabel(BetaFeedbackCaptureMoment? moment) {
    if (moment == null) return 'None';
    return moment.storageValue;
  }

  static String panelLatestAnswerLabel({
    required BetaFeedbackCaptureMoment? moment,
    required String? answerId,
  }) {
    if (moment == null || answerId == null || answerId.isEmpty) {
      return 'None';
    }
    return labelForAnswerId(moment, answerId);
  }
}
