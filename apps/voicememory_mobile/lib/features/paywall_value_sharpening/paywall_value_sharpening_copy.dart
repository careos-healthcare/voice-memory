import '../../billing/paywall_source.dart';

/// Proof-connected paywall copy — display only, no billing logic.
abstract final class PaywallValueSharpeningCopy {
  PaywallValueSharpeningCopy._();

  static const proofConnectedHeadline = 'Keep the proof trail behind this repeat';

  static const genericHeadline = 'Keep the longer proof trail.';

  static const body =
      'Free shows the first useful proof. Pro keeps what returned, changed, '
      'faded, or corrected over time.';

  static const proofConnectedLine =
      'The value is not more chat. It is the longer evidence trail.';

  static const cta = 'Keep the longer trail';

  static const secondaryReassurance =
      'You stay in control. You can delete entries and correct what you saved.';

  static const benefitBullets = <String>[
    'Longer proof trail',
    'Correction history',
    'Current vs fading signals',
    'Longer evidence trail',
    'What returned over time',
    'Trail continuity over weeks',
  ];

  static const corePaidReason = 'Keep the longer proof trail.';

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
