/// Canonical website ↔ app continuity copy — mirrors web landing alignment v1.
abstract final class LandingAppContinuityCopy {
  LandingAppContinuityCopy._();

  static const subheadline = 'No daily journal required.';

  static const hero = 'See what keeps returning';

  static const heroBody =
      'Save small moments when something stands out. ArchiveMe turns them into a '
      'private timeline of what appeared, what returned, what you corrected, and '
      'what still matters now.';

  static const chatGptDifferentiation =
      'ChatGPT can answer a conversation. ArchiveMe shows the timeline behind the pattern.';

  static const proPaidReason = 'Pro keeps the full timeline as it grows.';

  static const freePositioning =
      'Free shows the first proof. Pro keeps the full timeline as it grows.';

  static const step1Title = 'Save one small moment';
  static const step1Body =
      'When something stands out, save it in your own words on this device.';

  static const step2Title = 'Come back when something stands out';
  static const step2Body =
      'No daily streak required. Return when another moment matters.';

  static const step3Title = 'See what returned';
  static const step3Body =
      'After a few saves, see what appeared, returned, or went quiet.';

  static const step4Title = 'Correct what is not relevant';
  static const step4Body = 'Mark what does not fit. Your timeline stays yours.';

  static const step5Title = 'Keep the full timeline with Pro';
  static const step5Body = freePositioning;

  static const howItWorksStepTitles = <String>[
    step1Title,
    step2Title,
    step3Title,
    step4Title,
    step5Title,
  ];

  static List<String> allVisibleStrings() => [
        subheadline,
        hero,
        heroBody,
        chatGptDifferentiation,
        proPaidReason,
        freePositioning,
        step1Title,
        step1Body,
        step2Title,
        step2Body,
        step3Title,
        step3Body,
        step4Title,
        step4Body,
        step5Title,
        step5Body,
      ];
}
