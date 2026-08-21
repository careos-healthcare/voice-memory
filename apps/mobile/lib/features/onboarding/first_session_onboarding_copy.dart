/// User-facing copy for first-session onboarding on Record — loop only.
abstract final class FirstSessionOnboardingCopy {
  FirstSessionOnboardingCopy._();

  static const title = 'When it repeats, save it';

  static const body =
      'Not a diary. Not ChatGPT. Not homework. Save one real moment when you '
      'notice something coming back — ArchiveMe compares it later.';

  static const step1Title = 'Save one real moment';
  static const step1Body =
      'One real sentence is enough. No perfect journal required.';

  static const step2Title = 'Come back when it repeats';
  static const step2Body =
      'Save the repeat here because ArchiveMe compares it later.';

  static const step3Title = 'See what ArchiveMe compares';
  static const step3Body =
      'After enough real moments, the first useful proof can appear.';

  static const startCta = 'Start with a moment';
  static const exploreCta = "I'll explore first";

  static const notChatFootnote =
      'ChatGPT can suggest what to do. ArchiveMe shows what you already said before.';

  static const steps = <({String title, String body})>[
    (title: step1Title, body: step1Body),
    (title: step2Title, body: step2Body),
    (title: step3Title, body: step3Body),
  ];
}