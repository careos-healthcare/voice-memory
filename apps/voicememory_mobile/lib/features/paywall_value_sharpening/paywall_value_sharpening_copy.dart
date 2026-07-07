import '../../billing/paywall_source.dart';

/// Proof-connected paywall copy — display only, no billing logic.
abstract final class PaywallValueSharpeningCopy {
  PaywallValueSharpeningCopy._();

  static const proofConnectedHeadline = 'Keep the timeline behind this proof';

  static const genericHeadline = 'Keep the full timeline';

  static const body =
      'Free shows the first proof. Pro keeps what appeared, what returned, '
      'what you corrected, and what still matters as the timeline grows.';

  static const proofConnectedLine =
      'The value is not more chat. It is the longer evidence trail.';

  static const cta = 'Keep my full timeline';

  static const secondaryReassurance =
      'You stay in control. You can delete entries and correct the timeline.';

  static const benefitBullets = <String>[
    'Full pattern timeline',
    'Correction history',
    'Current vs fading signals',
    'Longer evidence trail',
    'Monthly private report',
    'Backup and continuity',
  ];

  static const corePaidReason = 'Keep the full timeline.';

  static const bannedFakeClaims = <String>[
    'limited time',
    'only today',
    'testimonial',
    'users say',
    '5-star',
  ];

  static bool isProofConnectedSource(PaywallSource? source) =>
      source == PaywallSource.valueMoment;

  static String headlineFor(PaywallSource? source) =>
      isProofConnectedSource(source)
          ? proofConnectedHeadline
          : genericHeadline;

  static PaywallSourceCopy sourceCopyFor(PaywallSource source) {
    if (isProofConnectedSource(source)) {
      return proofConnected;
    }
    return PaywallSourceCopy.forSource(source);
  }

  static const proofConnected = PaywallSourceCopy(
    headline: proofConnectedHeadline,
    subheadline: body,
    bullets: benefitBullets,
    cta: cta,
  );

  static List<String> allPaywallStrings() => [
        proofConnectedHeadline,
        genericHeadline,
        body,
        proofConnectedLine,
        cta,
        secondaryReassurance,
        ...benefitBullets,
      ];
}
