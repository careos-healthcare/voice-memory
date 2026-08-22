/// When to schedule the next evidence reminder.
enum ReminderTimingVariant {
  tomorrowMorning,
  tomorrowEvening,
  sameTimeTomorrow,
  routineAnchor,
}

extension ReminderTimingVariantIds on ReminderTimingVariant {
  String get id => name;

  String get label {
    switch (this) {
      case ReminderTimingVariant.tomorrowMorning:
        return 'Tomorrow morning';
      case ReminderTimingVariant.tomorrowEvening:
        return 'Tomorrow evening';
      case ReminderTimingVariant.sameTimeTomorrow:
        return 'Same time tomorrow';
      case ReminderTimingVariant.routineAnchor:
        return 'My usual time';
    }
  }
}

/// Outcome of offering reminder timing.
class ReminderTimingOffer {
  const ReminderTimingOffer({
    required this.offeredVariants,
    this.selectedVariant,
    this.offeredAt,
    this.dismissed = false,
  });

  final List<ReminderTimingVariant> offeredVariants;
  final ReminderTimingVariant? selectedVariant;
  final DateTime? offeredAt;
  final bool dismissed;
}

/// Scheduled reminder with safe notification copy.
class ReminderSchedulePlan {
  const ReminderSchedulePlan({
    required this.when,
    required this.variant,
    required this.title,
    required this.body,
    required this.journeyId,
  });

  final DateTime when;
  final ReminderTimingVariant variant;
  final String title;
  final String body;
  final String journeyId;
}