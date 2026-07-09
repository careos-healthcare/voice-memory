import 'pricing_value_framing_model.dart';

/// Pricing value framing copy — beta/testing only, pre-paywall decision framing.
abstract final class PricingValueFramingCopy {
  PricingValueFramingCopy._();

  static const title = 'Is Pro worth it?';
  static const body =
      'Only if you want ArchiveMe to keep the evidence trail after the first proof.';
  static const valueExplanation =
      'Free can show the first useful signal. Pro is for the longer record: '
      'whether the pattern keeps returning, starts softening, disappears, '
      'or needs correcting.';
  static const bulletKeepHistory = 'Keep the pattern history';
  static const bulletSeeChanges = 'See whether it changes';
  static const bulletCorrectArchive = 'Correct the archive when it is wrong';
  static const reassurance =
      'No pressure to decide now. The question is whether the longer trail '
      'would be useful to you.';
  static const primaryCta = 'See the Pro timeline';
  static const secondaryCta = 'Keep using free';
  static const feedbackPrompt =
      'Would you pay to keep this longer trail?';
  static const feedbackYes = 'Yes';
  static const feedbackMaybe = 'Maybe';
  static const feedbackNo = 'No';

  static const bullets = [
    bulletKeepHistory,
    bulletSeeChanges,
    bulletCorrectArchive,
  ];

  static String feedbackLabel(PricingValueFramingFeedbackType type) =>
      switch (type) {
        PricingValueFramingFeedbackType.yes => feedbackYes,
        PricingValueFramingFeedbackType.maybe => feedbackMaybe,
        PricingValueFramingFeedbackType.no => feedbackNo,
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield title;
    yield body;
    yield valueExplanation;
    yield bulletKeepHistory;
    yield bulletSeeChanges;
    yield bulletCorrectArchive;
    yield reassurance;
    yield primaryCta;
    yield secondaryCta;
    yield feedbackPrompt;
    yield feedbackYes;
    yield feedbackMaybe;
    yield feedbackNo;
  }
}
