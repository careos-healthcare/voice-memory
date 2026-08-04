import '../../product/auditable_change_positioning.dart';
import '../../product/core_product_vision.dart';

/// Canonical website ↔ app continuity copy — mirrors web landing alignment v1.
abstract final class LandingAppContinuityCopy {
  LandingAppContinuityCopy._();

  static const coreProductVision = CoreProductVision.valueProposition;

  static const category = AuditableChangePositioning.category;

  static const subheadline =
      'Auditable personal change. Speak naturally, keep it private, and check '
      'the saved words behind every comparison.';

  static const hero = AuditableChangePositioning.primaryPromise;

  static const heroBody = coreProductVision;

  static const publicPromise = coreProductVision;

  static const chatGptDifferentiation =
      'ChatGPT can suggest what to do. ArchiveMe shows what you already said before.';

  static const notesDifferentiation =
      'Notes store what happened. ArchiveMe checks what returns.';

  static const proPaidReason = 'Pro keeps the longer proof trail over time.';

  static const freePositioning =
      'Free shows the first useful proof. Pro keeps the longer proof trail.';

  static const step1Title = 'Save one real moment';
  static const step1Body = 'Speak or type what happened, in your own words.';

  static const step2Title = 'See what repeated';
  static const step2Body =
      'Returning with a related moment gives ArchiveMe something to compare.';

  static const step3Title = 'Check the words proving it';
  static const step3Body =
      'Every comparison opens the exact saved words and dates behind it.';

  static const step4Title = 'Correct what is not relevant';
  static const step4Body =
      'Mark what does not fit. Your proof trail stays yours.';

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
    coreProductVision,
    publicPromise,
    subheadline,
    hero,
    heroBody,
    chatGptDifferentiation,
    notesDifferentiation,
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
