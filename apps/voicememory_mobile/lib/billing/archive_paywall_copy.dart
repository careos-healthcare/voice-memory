import '../product/consumer_ui_copy.dart';

/// Subscription paywall copy — calm, consumer-facing launch copy.
abstract final class ArchivePaywallCopy {
  ArchivePaywallCopy._();

  static const String screenTitle = 'ArchiveMe Pro';

  static const String headline = ConsumerUiCopy.paywallHeadline;
  static const String headlineB = headline;

  static const String subheadline = ConsumerUiCopy.paywallSubhead;
  static const String subheadlineBParagraph1 = subheadline;
  static const String subheadlineBParagraph2 =
      'Pro keeps key moments, pattern map, and what ArchiveMe remembers as you record more.';

  static const String subheadlineA = subheadline;

  static const String primaryCta = ConsumerUiCopy.paywallPrimaryCta;
  static const String secondaryCta = ConsumerUiCopy.paywallSecondaryCta;

  static const List<String> benefits = ConsumerUiCopy.paywallBullets;
  static const List<String> keyValueBullets = benefits;

  static const String keyValueTitle =
      'The most useful patterns show up over time.';

  static const String lockedSectionTitle = 'Included with ArchiveMe Pro';

  static const String heroGeneratedFromLabel = 'Generated from';
  static const String heroAcrossLabel = 'across';

  static const String theoryPreviewLabel = 'A pattern ArchiveMe is noticing';
  static const String basedOnLabel = 'Based on your moments';
  static const String momentCountLabel = 'Moments reviewed';

  static const String preCtaFallback =
      'Pattern memory gets clearer as you add more moments over weeks and months.';

  static const String proActiveTitle = 'ArchiveMe Pro is active';
  static const String proActiveBody = ConsumerUiCopy.paywallProActiveBody;

  static const String socialProofTitleA = 'People return to ArchiveMe to see';
  static const List<String> socialProofBulletsA = [
    'which patterns changed',
    'what kept repeating',
    'what felt worth noticing',
  ];
}

class ArchivePaywallLockedCard {
  const ArchivePaywallLockedCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;
}

enum ArchivePaywallVariant {
  b,
}

abstract final class ArchivePaywallVariantConfig {
  ArchivePaywallVariantConfig._();

  static const ArchivePaywallVariant defaultVariant = ArchivePaywallVariant.b;

  static ArchivePaywallVariant get active => defaultVariant;

  static String headline(ArchivePaywallVariant variant) =>
      ArchivePaywallCopy.headline;

  static List<ArchivePaywallLockedCard> lockedCards(
    ArchivePaywallVariant variant,
  ) =>
      ArchivePaywallCopy.benefits
          .map(
            (b) => ArchivePaywallLockedCard(
              title: b,
              subtitle: ArchivePaywallCopy.subheadline,
            ),
          )
          .toList();

  static bool useKeyValueSection(ArchivePaywallVariant variant) => true;

  static bool useSocialProofSection(ArchivePaywallVariant variant) => false;
}
