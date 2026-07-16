import '../paywall_alignment/paywall_alignment_copy.dart';

/// Display-only Pro packaging copy — free vs Pro value split.
abstract final class ProPackagingCopy {
  ProPackagingCopy._();

  static const title = 'ArchiveMe Pro';

  static const subtitle = PaywallAlignmentCopy.body;

  static const freeSectionTitle = 'Free';
  static const freeBullets = <String>[
    'Start your archive and unlock your first proof.',
  ];

  static const proSectionTitle = 'Pro';
  static const proBullets = PaywallAlignmentCopy.benefitBullets;

  static const bridgeAfterFirstProof = PaywallAlignmentCopy.secondaryReassurance;

  static const bridgeAfterBeliefChange =
      'Seeing change over time is the reason to keep your archive.';

  static const continueCta = 'Continue';
  static const continueWithoutProCta = 'Continue without Pro';
  static const restorePurchases = 'Restore purchases';

  static const offeringsUnavailableBody =
      'Monthly and yearly plans will appear when App Store products finish loading.';

  static const accountTileSubtitle = subtitle;

  static Iterable<String> allVisibleCopy() sync* {
    yield title;
    yield subtitle;
    yield freeSectionTitle;
    yield* freeBullets;
    yield proSectionTitle;
    yield* proBullets;
    yield bridgeAfterFirstProof;
    yield bridgeAfterBeliefChange;
    yield continueCta;
    yield continueWithoutProCta;
    yield restorePurchases;
    yield offeringsUnavailableBody;
    yield accountTileSubtitle;
  }
}
