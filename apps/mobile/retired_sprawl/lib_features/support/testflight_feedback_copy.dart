/// Copy for the Settings TestFlight feedback email link.
abstract final class TestFlightFeedbackCopy {
  TestFlightFeedbackCopy._();

  static const settingsTitle = 'Testing ArchiveMe?';

  static const settingsCta = 'Send feedback';

  static const unavailableMessage =
      'Tester guidance is not available in this build.';

  static const emailTo = 'hello@archiveme.app';

  static const emailSubject = 'ArchiveMe TestFlight feedback';

  static const emailBody = '''
Hi ArchiveMe team,

I tested ArchiveMe and noticed:

What felt clear:


What felt confusing:


What I expected to happen:


Device:


Thanks.''';

  static const emailFallbackMessage =
      'Could not open email. Please send feedback to hello@archiveme.app.';
}