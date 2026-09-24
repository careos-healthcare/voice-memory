/// When to request GPT archive synthesis (pilot).
abstract class ArchiveSynthesisTrigger {
  ArchiveSynthesisTrigger._();

  static const int minEligible = 50;
  static const List<int> milestones = [50, 100, 200, 500];

  static String monthKeyFor(DateTime local) {
    final l = local.toLocal();
    final m = l.month.toString().padLeft(2, '0');
    return '${l.year}-$m';
  }

  /// Monthly review due if no stored review for [monthKey].
  static bool isMonthlyReviewDue({
    required String monthKey,
    required String? lastReviewMonthKey,
  }) => lastReviewMonthKey != monthKey;

  /// New milestone crossed since [celebratedMilestones].
  static int? newlyReachedMilestone({
    required int eligibleCount,
    required Set<int> celebratedMilestones,
  }) {
    for (final m in milestones) {
      if (eligibleCount >= m && !celebratedMilestones.contains(m)) {
        return m;
      }
    }
    return null;
  }

  static bool shouldRequestSynthesis({
    required int eligibleCount,
    required String monthKey,
    required String? lastReviewMonthKey,
    required Set<int> celebratedMilestones,
    required String? cachedArchiveHash,
    required String currentArchiveHash,
  }) {
    if (eligibleCount < minEligible) return false;
    if (cachedArchiveHash == currentArchiveHash) return false;

    final monthlyDue = isMonthlyReviewDue(
      monthKey: monthKey,
      lastReviewMonthKey: lastReviewMonthKey,
    );
    final milestone = newlyReachedMilestone(
      eligibleCount: eligibleCount,
      celebratedMilestones: celebratedMilestones,
    );
    return monthlyDue || milestone != null;
  }
}
