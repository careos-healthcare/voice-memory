import '../landing_continuity/landing_app_continuity_copy.dart';
import '../paywall_alignment/paywall_alignment_copy.dart';

/// Display-only copy for Pro moment timing — no billing logic.
abstract final class ProMomentTimingCopy {
  ProMomentTimingCopy._();

  static const coreRule =
      'Free shows the first proof. Pro keeps the full timeline as it grows.';

  static const headline = PaywallAlignmentCopy.headline;

  static const body = PaywallAlignmentCopy.body;

  static const compactLine = LandingAppContinuityCopy.proPaidReason;
}
