/// Which part of the local day a blank-entry prompt belongs to.
enum TimeOfDayPromptKind {
  morningReflection,
  middayCheckIn,
  eveningDebrief,
}

/// Copy shown when entry creation has no text yet.
class TimeOfDayPrompt {
  const TimeOfDayPrompt({
    required this.kind,
    required this.title,
    required this.body,
  });

  static const morning = TimeOfDayPrompt(
    kind: TimeOfDayPromptKind.morningReflection,
    title: 'Morning Reflection',
    body: 'What do you want to remember from the start of today?',
  );

  static const midday = TimeOfDayPrompt(
    kind: TimeOfDayPromptKind.middayCheckIn,
    title: 'Midday Check-In',
    body: 'What is worth keeping from the middle of the day?',
  );

  static const evening = TimeOfDayPrompt(
    kind: TimeOfDayPromptKind.eveningDebrief,
    title: 'Evening Debrief',
    body: "What should today's debrief hold onto?",
  );

  /// Morning is 05:00–11:59, midday is 12:00–16:59, and every other local
  /// hour is an evening debrief. [instant] is read in local time.
  static TimeOfDayPrompt resolve(DateTime instant) {
    final hour = instant.toLocal().hour;
    if (hour >= 5 && hour < 12) return morning;
    if (hour >= 12 && hour < 17) return midday;
    return evening;
  }

  final TimeOfDayPromptKind kind;
  final String title;
  final String body;
}
