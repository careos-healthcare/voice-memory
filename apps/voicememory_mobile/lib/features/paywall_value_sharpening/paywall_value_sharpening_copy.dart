import '../../billing/paywall_source.dart';

/// Proof-connected paywall copy — display only, no billing logic.
abstract final class PaywallValueSharpeningCopy {
  PaywallValueSharpeningCopy._();

  static const proofConnectedHeadline = 'You saw the first useful repeat.';

  static const genericHeadline = proofConnectedHeadline;

  /// Anchor positioning line — evidence-based framing shown directly under
  /// the headline on every paywall variant. Longer history and verified
  /// change over time, never "more chat" or a promised transformation.
  static const anchorPositioningLine = 'Keep your verified timeline growing.';

  static const body =
      'Free shows the first useful proof. Pro keeps the longer trail.';

  static const proofConnectedLine =
      'Pro keeps a longer private archive — more moments, more continuity, '
      'more evidence over time.';

  static const cta = 'Keep the longer trail';

  static const secondaryReassurance =
      'You stay in control. You can delete entries and correct what you saved.';

  static const benefitBullets = <String>[
    'Longer evidence history on this device',
    'More archived moments over weeks and months',
    'Continuity when patterns return or change',
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
      isProofConnectedSource(source) ? proofConnectedHeadline : genericHeadline;

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
    anchorPositioningLine,
    body,
    proofConnectedLine,
    cta,
    secondaryReassurance,
    ...benefitBullets,
  ];
}
