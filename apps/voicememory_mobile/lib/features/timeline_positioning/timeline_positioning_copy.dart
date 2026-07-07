import 'timeline_positioning_model.dart';

/// Copy for not-a-chat timeline positioning — differentiation only, no attacks.
abstract final class TimelinePositioningCopy {
  TimelinePositioningCopy._();

  static const coreLine = 'Not a chat. A timeline of what keeps returning.';

  static const title = 'Not a chat. A timeline.';

  static const body =
      'ArchiveMe does not try to answer everything. It shows what your saved '
      'moments are proving over time.';

  static const differentiationLine =
      'ChatGPT helps with this conversation. ArchiveMe shows the timeline behind it.';

  static const List<String> timelineBullets = [
    'First seen',
    'Returned',
    'Still current',
    'Fading',
    'Softened',
    'Changed',
  ];

  static const proBridgeLine = 'Pro keeps the timeline as it grows.';

  static const supportingTodayConnection =
      'ChatGPT can help with what you ask today. ArchiveMe shows whether today '
      'connects to what has kept returning.';

  static const supportingNotMoreConversation =
      'ArchiveMe is not more AI conversation. It is a private evidence trail '
      'built from moments you saved.';

  static const supportingValueOverTime =
      'The value is not more answers. The value is seeing what changed over time.';

  static const supportingProTimeline =
      'Pro keeps the timeline, not just the moment.';

  static const List<String> all = [
    coreLine,
    title,
    body,
    differentiationLine,
    ...timelineBullets,
    proBridgeLine,
    supportingTodayConnection,
    supportingNotMoreConversation,
    supportingValueOverTime,
    supportingProTimeline,
  ];

  static String bulletKey(String bullet) => 'timeline_positioning_bullet_$bullet';
}
