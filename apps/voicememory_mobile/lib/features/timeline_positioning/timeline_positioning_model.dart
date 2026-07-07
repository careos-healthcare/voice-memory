import 'timeline_positioning_copy.dart';

/// Resolved timeline positioning card — copy and safe metadata only.
class TimelinePositioningResult {
  const TimelinePositioningResult({
    required this.shouldShow,
    required this.entryCount,
    required this.source,
    required this.hasConfirmedRepeat,
    required this.hasBeliefSurface,
    required this.title,
    required this.body,
    required this.differentiationLine,
    required this.timelineBullets,
    required this.proBridgeLine,
  });

  final bool shouldShow;
  final int entryCount;
  final String source;
  final bool hasConfirmedRepeat;
  final bool hasBeliefSurface;
  final String title;
  final String body;
  final String differentiationLine;
  final List<String> timelineBullets;
  final String proBridgeLine;
}
