import 'package:archiveme_mobile/features/landing_continuity/landing_app_continuity_copy.dart';
import 'package:archiveme_mobile/features/paywall_alignment/paywall_alignment_copy.dart';

/// Display-only copy for Pro moment timing — no billing logic.
abstract final class ProMomentTimingCopy {
  ProMomentTimingCopy._();

  static const coreRule =
      'Free shows the first useful proof. Pro keeps the longer proof trail over time.';

  static const String headline = PaywallAlignmentCopy.headline;

  static const String body = PaywallAlignmentCopy.body;

  static const String compactLine = LandingAppContinuityCopy.proPaidReason;
}