import '../signal_journey/signal_journey_model.dart';

/// Whether the return-day journey card should dominate the Record tab.
class ReturnDayJourneyDecision {
  const ReturnDayJourneyDecision({
    required this.showCard,
    this.recordedToday = false,
  });

  final bool showCard;
  final bool recordedToday;

  static const hidden = ReturnDayJourneyDecision(showCard: false);
}

/// Detects next-day return with an active signal journey.
class ReturnDayJourneyEngine {
  const ReturnDayJourneyEngine();

  ReturnDayJourneyDecision evaluate({
    required SignalJourney? journey,
    required int reflectionCount,
    required DateTime now,
    DateTime? lastReflectionAt,
  }) {
    if (journey == null || !journey.isActive) {
      return ReturnDayJourneyDecision.hidden;
    }
    if (reflectionCount < 1) return ReturnDayJourneyDecision.hidden;

    final startedDay = DateTime(
      journey.startedAt.year,
      journey.startedAt.month,
      journey.startedAt.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    if (!today.isAfter(startedDay)) {
      return ReturnDayJourneyDecision.hidden;
    }

    var recordedToday = false;
    if (lastReflectionAt != null) {
      final lastDay = DateTime(
        lastReflectionAt.year,
        lastReflectionAt.month,
        lastReflectionAt.day,
      );
      recordedToday = lastDay == today;
    }

    return ReturnDayJourneyDecision(
      showCard: true,
      recordedToday: recordedToday,
    );
  }
}
