/// Copy for the Settings TestFlight feedback email link.
abstract final class TestFlightFeedbackCopy {
  TestFlightFeedbackCopy._();

  static const settingsTitle = 'Testing Thoughtprint?';

  static const settingsCta = 'Send feedback';

  static const unavailableMessage =
      'Tester guidance is not available in this build.';

  static const emailTo = 'hello@thoughtprint.xyz';

  static const emailSubject = 'Thoughtprint TestFlight feedback';

  static const emailBody = '''
Hi Thoughtprint team,

I tested Thoughtprint and noticed:

What felt clear:


What felt confusing:


What I expected to happen:


Device:


Thanks.''';

  static const emailFallbackMessage =
      'Could not open email. Please send feedback to hello@thoughtprint.xyz.';
}