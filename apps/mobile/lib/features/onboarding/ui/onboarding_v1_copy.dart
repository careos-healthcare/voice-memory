import 'package:archiveme_mobile/features/settings/ui/trust_badge_copy.dart';
import 'package:archiveme_mobile/security/privacy_claim_catalogue.dart';

/// V1 onboarding copy — product contract and trust pillars.
///
/// Pillars 2 and 3 are the first-run form of the statement in
/// `lib/features/settings/ui/on_device_architecture_copy.dart`: processing is
/// on-device *by default* rather than exclusively, because
/// `RemoteProcessingConsentStore` gates real uploads; and storage protection
/// is read off the live status rather than asserted, because
/// `SecureSqliteLockService.encryptionEnabled` is a runtime property of the
/// build. Both bodies are composed from [PrivacyClaimCatalogue] so they stay
/// worded in one place.
///
/// Their titles are taken from [TrustBadgeCopy] rather than retyped. The two
/// used to be byte-identical by coincidence, which is how the welcome screen
/// ended up rendering the same heading twice — once via `TrustBadge` and once
/// via `OnboardingTrustPillarsSection` — and why `findsOneWidget` reported two
/// matches. Aliasing makes the shared wording deliberate: a screen may render
/// one of these or the other, never both.
abstract final class OnboardingV1Copy {
  OnboardingV1Copy._();

  static const welcomeTitle =
      'A private voice archive of what you actually said';

  static const welcomeBody =
      'ArchiveMe preserves your voice and text moments on this device. '
      'Over time it may show cautious, evidence-backed changes — always with '
      'your own words cited behind them. It does not diagnose, treat, or '
      'promise transformation.';

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
