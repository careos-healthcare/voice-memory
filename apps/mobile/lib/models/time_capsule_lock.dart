/// Lock state stored on a journal row for a time capsule.
///
/// A capsule stays closed until its date has arrived or the archive has
/// reached [unlockMilestoneEntryCount], whichever condition is set.
final class TimeCapsuleLock {
  const TimeCapsuleLock({
    required this.isTimeCapsule,
    this.unlockDateMillis,
    this.unlockMilestoneEntryCount,
  });

  final bool isTimeCapsule;

  /// UTC milliseconds, matching `journal_entries.created_at`.
  final int? unlockDateMillis;

  /// Active entry count that opens the capsule.
  final int? unlockMilestoneEntryCount;

  bool isUnlocked({
    required int nowMillis,
    required int activeEntryCount,
  }) {
    if (!isTimeCapsule) return true;
    final dateOpen = unlockDateMillis != null && unlockDateMillis! <= nowMillis;
    final milestoneOpen =
        unlockMilestoneEntryCount != null &&
        activeEntryCount >= unlockMilestoneEntryCount!;
    return dateOpen || milestoneOpen;
  }

  static TimeCapsuleLock fromRow(Map<String, Object?> row) {
    return TimeCapsuleLock(
      isTimeCapsule: (row['is_time_capsule'] as int? ?? 0) == 1,
      unlockDateMillis: row['unlock_date'] as int?,
      unlockMilestoneEntryCount: row['unlock_milestone_entry_count'] as int?,
    );
  }
}
