/// Canonical website ↔ app continuity copy — mirrors web landing alignment v1.
abstract final class LandingAppContinuityCopy {
  LandingAppContinuityCopy._();

  static const publicPromise =
      'When something repeats, save one real moment. ArchiveMe compares it later.';

  static const subheadline = 'No daily journal. No streak. No dashboard to maintain.';

  static const hero = 'When it repeats, save it';

  static const heroBody =
      '$publicPromise Not a diary. Not ChatGPT. Not homework.';

  static const chatGptDifferentiation =
      'ChatGPT answers a conversation. ArchiveMe keeps the evidence trail.';

  static const proPaidReason = 'Pro keeps the longer proof trail over time.';

  static const freePositioning =
      'Free shows the first useful proof. Pro keeps the longer proof trail.';

  static const step1Title = 'Save one real moment';
  static const step1Body =
      'When something repeats, save it in your own words on this device.';

  static const step2Title = 'Come back when it repeats';
  static const step2Body =
      'ArchiveMe compares saved moments later — cautiously, not as homework.';

  static const step3Title = 'See what appeared and returned';
  static const step3Body =
      'After a few saves, see what appeared, returned, changed, faded, or got corrected.';

  static const step4Title = 'Correct what is not relevant';
  static const step4Body = 'Mark what does not fit. Your proof trail stays yours.';

  static const step5Title = 'Keep the longer proof trail with Pro';
  static const step5Body = freePositioning;

  static const howItWorksStepTitles = <String>[
    step1Title,
    step2Title,
    step3Title,
    step4Title,
    step5Title,
  ];

  static List<String> allVisibleStrings() => [
        publicPromise,
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
