/// A small win that can open the upgrade sheet once it is completed.
enum PaywallMicroWin {
  threeDayStreak,
  fiveCompletedArchives,
}

/// Saved-archive and streak progress used to decide when the paywall opens.
class PaywallMilestoneSnapshot {
  const PaywallMilestoneSnapshot({
    required this.completedArchives,
    required this.activeDayKeys,
    required this.celebrated,
    required this.hasBaseline,
    required this.asOf,
    this.pending,
  });

  static final initial = PaywallMilestoneSnapshot(
    completedArchives: 0,
    activeDayKeys: const {},
    celebrated: const {},
    hasBaseline: false,
    asOf: DateTime.utc(1970),
  );

  final int completedArchives;
  final Set<String> activeDayKeys;
  final Set<PaywallMicroWin> celebrated;
  final bool hasBaseline;
  final DateTime asOf;
  final PaywallMicroWin? pending;

  PaywallMilestoneSnapshot copyWith({
    int? completedArchives,
    Set<String>? activeDayKeys,
    Set<PaywallMicroWin>? celebrated,
    bool? hasBaseline,
    DateTime? asOf,
    PaywallMicroWin? pending,
    bool clearPending = false,
  }) {
    return PaywallMilestoneSnapshot(
      completedArchives: completedArchives ?? this.completedArchives,
      activeDayKeys: activeDayKeys ?? this.activeDayKeys,
      celebrated: celebrated ?? this.celebrated,
      hasBaseline: hasBaseline ?? this.hasBaseline,
      asOf: asOf ?? this.asOf,
      pending: clearPending ? null : pending ?? this.pending,
    );
  }
}

/// Duolingo-style gates: the sheet opens when a win is completed, not on tap.
abstract final class PaywallMilestoneEngine {
  PaywallMilestoneEngine._();

  static const streakTarget = 3;
  static const archiveTarget = 5;

  static String dayKey(DateTime value) {
    final utc = value.toUtc();
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$month-$day';
  }

  static int consecutiveStreak(Set<String> dayKeys, DateTime today) {
    final utc = today.toUtc();
    var cursor = DateTime.utc(utc.year, utc.month, utc.day);
    if (!dayKeys.contains(dayKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (dayKeys.contains(dayKey(cursor))) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static PaywallMilestoneSnapshot record({
    required PaywallMilestoneSnapshot current,
    required int activeCountAfter,
    required Set<String> activeDayKeys,
    required DateTime savedAt,
    required bool isFirstEntryOnSavedDay,
  }) {
    final savedDay = dayKey(savedAt);
    final previousCount = current.hasBaseline
        ? current.completedArchives
        : activeCountAfter - 1;
    final previousKeys = current.hasBaseline
        ? current.activeDayKeys
        : isFirstEntryOnSavedDay
        ? (Set<String>.from(activeDayKeys)..remove(savedDay))
        : Set<String>.from(activeDayKeys);
    final previousStreak = consecutiveStreak(previousKeys, savedAt);
    final nextStreak = consecutiveStreak(activeDayKeys, savedAt);
    final celebrated = Set<PaywallMicroWin>.from(current.celebrated);
    var pending = current.pending;

    void cross(
      PaywallMicroWin win, {
      required bool wasBelow,
      required bool isMet,
    }) {
      if (pending != null || celebrated.contains(win)) return;
      if (wasBelow && isMet) pending = win;
    }

    cross(
      PaywallMicroWin.fiveCompletedArchives,
      wasBelow: previousCount < archiveTarget,
      isMet: activeCountAfter >= archiveTarget,
    );
    cross(
      PaywallMicroWin.threeDayStreak,
      wasBelow: previousStreak < streakTarget,
      isMet: nextStreak >= streakTarget,
    );

    return PaywallMilestoneSnapshot(
      completedArchives: activeCountAfter,
      activeDayKeys: Set<String>.from(activeDayKeys),
      celebrated: celebrated,
      hasBaseline: true,
      asOf: savedAt,
      pending: pending,
    );
  }
}
