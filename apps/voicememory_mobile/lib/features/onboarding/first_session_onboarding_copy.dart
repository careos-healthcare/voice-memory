/// User-facing copy for first-session onboarding on Record — loop only.
abstract final class FirstSessionOnboardingCopy {
  FirstSessionOnboardingCopy._();

  static const title = 'Build your archive from real moments';

  static const body =
      'ArchiveMe does not need a perfect journal. Record small things, come back when something repeats, and your archive will show what changed.';

  static const step1Title = 'Record anything real';
  static const step1Body = 'A thought, a small win, pressure, or a quiet day.';

  static const step2Title = 'Come back when life repeats';
  static const step2Body = 'ArchiveMe compares your own words over time.';

  static const step3Title = 'See what changed';
  static const step3Body =
      'Look for repeats, softer moments, and what helped.';

  static const startCta = 'Start with a moment';
  static const exploreCta = "I'll explore first";

  static const notChatFootnote =
      'ArchiveMe is not a chat. It helps you notice what keeps returning.';

  static const steps = <({String title, String body})>[
    (title: step1Title, body: step1Body),
    (title: step2Title, body: step2Body),
    (title: step3Title, body: step3Body),
  ];
}
