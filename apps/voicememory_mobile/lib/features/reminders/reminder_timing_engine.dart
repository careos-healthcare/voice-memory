import '../../product/consumer_ui_copy.dart';
import '../routine/routine_anchor_model.dart';
import 'reminder_timing_model.dart';

/// Picks reminder timing variants and computes schedule times.
class ReminderTimingEngine {
  const ReminderTimingEngine();

  List<ReminderTimingVariant> offeredVariants({RoutineAnchor? routineAnchor}) {
    final variants = <ReminderTimingVariant>[
      ReminderTimingVariant.tomorrowMorning,
      ReminderTimingVariant.tomorrowEvening,
      ReminderTimingVariant.sameTimeTomorrow,
    ];
    if (routineAnchor != null) {
      variants.add(ReminderTimingVariant.routineAnchor);
    }
    return variants;
  }

  DateTime scheduleTime({
    required ReminderTimingVariant variant,
    DateTime? now,
    RoutineAnchor? routineAnchor,
  }) {
    final clock = now ?? DateTime.now();
    switch (variant) {
      case ReminderTimingVariant.tomorrowMorning:
        return DateTime(clock.year, clock.month, clock.day + 1, 8, 30);
      case ReminderTimingVariant.tomorrowEvening:
        return DateTime(clock.year, clock.month, clock.day + 1, 19, 0);
      case ReminderTimingVariant.sameTimeTomorrow:
        return clock.add(const Duration(hours: 24));
      case ReminderTimingVariant.routineAnchor:
        final hourMinute = _anchorHourMinute(routineAnchor);
        var target = DateTime(
          clock.year,
          clock.month,
          clock.day + 1,
          hourMinute.$1,
          hourMinute.$2,
        );
        if (!target.isAfter(clock)) {
          target = target.add(const Duration(days: 1));
        }
        return target;
    }
  }

  (int, int) _anchorHourMinute(RoutineAnchor? anchor) {
    switch (anchor?.type) {
      case RoutineAnchorType.morning:
        return (8, 0);
      case RoutineAnchorType.afterWork:
        return (17, 30);
      case RoutineAnchorType.evening:
        return (19, 0);
      case RoutineAnchorType.beforeSleep:
        return (21, 30);
      case RoutineAnchorType.afterHardMoment:
      case RoutineAnchorType.custom:
      case null:
        return (20, 0);
    }
  }

  ReminderSchedulePlan plan({
    required String journeyId,
    required ReminderTimingVariant variant,
    String? prompt,
    DateTime? now,
    RoutineAnchor? routineAnchor,
  }) {
    final body = _bodyFor(prompt);
    return ReminderSchedulePlan(
      when: scheduleTime(
        variant: variant,
        now: now,
        routineAnchor: routineAnchor,
      ),
      variant: variant,
      title: ConsumerUiCopy.nextEvidenceReminderTitle,
      body: body,
      journeyId: journeyId,
    );
  }

  String _bodyFor(String? prompt) {
    final trimmed = prompt?.trim() ?? '';
    if (trimmed.isEmpty) {
      return ConsumerUiCopy.nextEvidenceReminderBodyDefault;
    }
    final short = trimmed.length > 72
        ? '${trimmed.substring(0, 71)}…'
        : trimmed;
    return ConsumerUiCopy.nextEvidenceReminderBodyWithPrompt.replaceAll(
      '{prompt}',
      short,
    );
  }
}
