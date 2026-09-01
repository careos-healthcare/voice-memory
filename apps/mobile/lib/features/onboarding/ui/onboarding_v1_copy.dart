import 'package:archiveme_mobile/features/settings/ui/trust_badge_copy.dart';
import 'package:archiveme_mobile/security/privacy_claim_catalogue.dart';

/// V1 first-run copy — two screens: evidence (the product) and send choice.
///
/// The four [trustPillars] stay worded here so settings and tests can still
/// read them. First-run does not show them. Storage belongs on Settings →
/// Privacy (live report). Caregiver belongs on Caregiver & coach access.
abstract final class OnboardingV1Copy {
  OnboardingV1Copy._();

  static const welcomeTitle = 'When it comes back, we show you the words.';

  /// Same claim as the repeating-phrase picture: we show your wording.
  static const welcomeBody =
      'ArchiveMe is a private voice archive of what you actually said. '
      'When a phrase repeats, those moments sit next to each other — '
      'your wording, not a verdict. '
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
