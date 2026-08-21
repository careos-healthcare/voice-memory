/// V1 onboarding copy — product contract and trust pillars.
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

  static const pillar2Title = 'AI processing happens locally on this device';
  static const pillar2Body =
      'Language models run here first. Remote processing is optional, '
      'consent-gated, and off until you choose it.';

  static const pillar3Title = 'Data is secured via local SQLite encryption';
  static const pillar3Body =
      'Your journal file is encrypted on this device. The database key stays '
      'in secure device storage.';

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
