import 'package:archiveme_mobile/features/settings/ui/trust_badge_copy.dart';
import 'package:archiveme_mobile/security/privacy_claim_catalogue.dart';

/// V1 onboarding copy — welcome sentence plus the four trust commitments.
///
/// Welcome is the product sentence only. The four [trustPillars] stay
/// worded here so settings and tests can still read them; first-run no
/// longer dumps all four on screen 1. Pillars 2 and 3 still compose from
/// [PrivacyClaimCatalogue]. Their titles alias [TrustBadgeCopy] so a
/// screen may render the badge or a pillar, never both.
abstract final class OnboardingV1Copy {
  OnboardingV1Copy._();

  static const welcomeTitle =
      'A private voice archive of what you actually said';

  /// What the product is — not how proof works, and not what can leave.
  /// Those jobs belong to the evidence step and the consent step.
  static const welcomeBody =
      'ArchiveMe preserves your voice and text moments on this device. '
      'It does not diagnose, treat, or promise transformation.';

  static const trustPillarsHeading = 'How ArchiveMe earns trust';

  static const pillar1Title = 'Your words are cited as evidence';
  static const pillar1Body =
      'Patterns and changes link back to the entries you saved. You can '
      'inspect source proof before you rely on any read.';

  static const String pillar2Title = TrustBadgeCopy.onDeviceProcessing;
  static const pillar2Body =
      '${PrivacyClaimCatalogue.remoteProcessingIsAChoice} '
      '${PrivacyClaimCatalogue.remoteProcessingScopedToJob} '
      '${PrivacyClaimCatalogue.remoteProcessingOffSwitch}';

  static const String pillar3Title = TrustBadgeCopy.storage;
  static const pillar3Body =
      '${PrivacyClaimCatalogue.momentsStayLocal} '
      '${PrivacyClaimCatalogue.storageProtectionReportedLive}';

  static const pillar4Title = 'You control all access';
  static const pillar4Body =
      'Caregiver and observer grants require your explicit consent. Revoke '
      'access any time — nothing is shared without your say.';

  static const List<({String title, String body})> trustPillars = [
    (title: pillar1Title, body: pillar1Body),
    (title: pillar2Title, body: pillar2Body),
    (title: pillar3Title, body: pillar3Body),
    (title: pillar4Title, body: pillar4Body),
  ];

  static const continueCta = 'Continue';
  static const startCta = 'Start my archive';
}
