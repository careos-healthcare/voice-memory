import '../../billing/paywall_source.dart';
import '../monetization/domain/generated/monetization_policy.g.dart';

/// Proof-connected paywall copy — display only, no billing logic.
abstract final class PaywallValueSharpeningCopy {
  PaywallValueSharpeningCopy._();

  static const proofConnectedHeadline = MonetizationPolicy.paywallHeadline;

  static const genericHeadline = proofConnectedHeadline;

  static const body = MonetizationPolicy.paywallSupportingLine;

  static const proofConnectedLine = MonetizationPolicy.paywallSupportingLine;

  static const cta = 'Keep the longer trail';

  static const secondaryReassurance =
      'You stay in control. You can delete entries and correct what you saved.';

  static const benefitBullets = <String>[
    MonetizationPolicy.ongoingComparisons,
    MonetizationPolicy.deeperArchiveAnalysis,
    MonetizationPolicy.remoteTranscriptionAllowance,
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
    body,
    proofConnectedLine,
    cta,
    secondaryReassurance,
    ...benefitBullets,
  ];
}
