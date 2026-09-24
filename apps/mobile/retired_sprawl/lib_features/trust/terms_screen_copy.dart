/// In-app terms of use — calm consumer copy, no internal launch wording.
abstract class TermsScreenCopy {
  TermsScreenCopy._();

  static const String screenTitle = 'Terms of use';

  static const String lastUpdated = 'Last updated: June 2026';

  static const String intro =
      'By using ArchiveMe you agree to these terms. '
      'ArchiveMe helps you notice what keeps repeating in your own words.';

  static const String serviceTitle = 'What ArchiveMe is';
  static const String serviceBody =
      'ArchiveMe is a private archive for your own voice reflections. '
      'It is not therapy, medical advice, coaching, or emergency support.';

  static const String contentTitle = 'Your content';
  static const String contentBody =
      'You keep ownership of what you record. You are responsible for what '
      'you choose to speak, export, or share outside the app.';

  static const String acceptableUseTitle = 'Acceptable use';
  static const String acceptableUseBody =
      'Do not use ArchiveMe to store illegal content or to harass others. '
      'Do not attempt to reverse-engineer or abuse app services.';

  static const String subscriptionsTitle = 'Subscriptions';
  static const String subscriptionsBody =
      'Optional Pro features may be offered by subscription. Free limits may '
      'change with notice in the app or on the pricing page.';

  static const String liabilityTitle = 'Limitation of liability';
  static const String liabilityBody =
      'ArchiveMe is a software tool, not a crisis service. Summaries and '
      'patterns are based on your own words and are not medical or therapeutic '
      'guidance.';

  static const List<TermsSection> sections = [
    TermsSection(title: serviceTitle, body: serviceBody),
    TermsSection(title: contentTitle, body: contentBody),
    TermsSection(title: acceptableUseTitle, body: acceptableUseBody),
    TermsSection(title: subscriptionsTitle, body: subscriptionsBody),
    TermsSection(title: liabilityTitle, body: liabilityBody),
  ];

  static const List<String> all = [
    screenTitle,
    lastUpdated,
    intro,
    serviceTitle,
    serviceBody,
    contentTitle,
    contentBody,
    acceptableUseTitle,
    acceptableUseBody,
    subscriptionsTitle,
    subscriptionsBody,
    liabilityTitle,
    liabilityBody,
  ];
}

class TermsSection {
  const TermsSection({required this.title, required this.body});

  final String title;
  final String body;
}
