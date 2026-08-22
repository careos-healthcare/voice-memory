import 'package:archiveme_mobile/features/paywall_alignment/paywall_alignment_copy.dart';

/// Display-only Pro packaging copy — free vs Pro value split.
abstract final class ProPackagingCopy {
  ProPackagingCopy._();

  static const title = 'ArchiveMe Pro';

  static const String subtitle = PaywallAlignmentCopy.body;

  static const freeSectionTitle = 'Free';
  static const freeBullets = <String>[
    'Start your archive and unlock your first proof.',
  ];

  static const proSectionTitle = 'Pro';
  static const List<String> proBullets = PaywallAlignmentCopy.benefitBullets;

  static const String bridgeAfterFirstProof =
      PaywallAlignmentCopy.secondaryReassurance;

  static const bridgeAfterBeliefChange =
      'Seeing change over time is the reason to keep your archive.';

  static const continueCta = 'Continue';
  static const continueWithoutProCta = 'Continue without Pro';
  static const restorePurchases = 'Restore purchases';

  static const offeringsUnavailableBody =
      'Monthly and yearly plans will appear when App Store products finish loading.';

  static const String accountTileSubtitle = subtitle;

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