/// Copy for the standalone crisis-resources page, reachable from Settings.
///
/// Static and always available — not gated behind any capability flag, and
/// not connected to any detection, monitoring, or third-party notification.
/// ArchiveMe is not a crisis service; this page only signposts to
/// organizations that are.
abstract final class CrisisResourcesCopy {
  CrisisResourcesCopy._();

  static const String settingsTitle = 'Crisis Support';
  static const String settingsSubtitle =
      'Resources if you need to talk to someone right now.';

  static const String screenTitle = 'Crisis Support';

  static const String intro =
      "If you're in crisis or worried about your safety, these resources "
      'are staffed by trained counselors, day or night.';

  static const String disclaimer =
      "ArchiveMe isn't a crisis service and can't respond in real time — "
      'these organizations can.';

  static const String emergencyTitle = 'In an immediate emergency';
  static const String emergencyBody = 'Call 911, or your local emergency number.';

  static const String lifelineTitle = '988 Suicide & Crisis Lifeline';
  static const String lifelineDescription =
      'Call or text 988. Free, confidential, available 24/7.';
  static const String lifelineCallAction = 'Call 988';
  static const String lifelineTextAction = 'Text 988';
  static const String lifelineCallUrl = 'tel:988';
  static const String lifelineTextUrl = 'sms:988';

  static const String crisisTextLineTitle = 'Crisis Text Line';
  static const String crisisTextLineDescription =
      'Text HOME to 741741. Free, confidential, available 24/7.';
  static const String crisisTextLineAction = 'Text 741741';
  static const String crisisTextLineUrl = 'sms:741741?body=HOME';

  static const String internationalTitle = 'Outside the United States';
  static const String internationalBody =
      'findahelpline.com lists verified crisis lines by country.';
  static const String internationalAction = 'Find a helpline';
  static const String internationalUrl = 'https://findahelpline.com';

  static const String linkErrorFallback = 'Could not open this link.';
}
