/// Evidence-backed weekly archive summary (no invented stats).
class WeeklyArchiveStory {
  const WeeklyArchiveStory({
    required this.weekStart,
    required this.weekEnd,
    required this.topThemes,
    required this.growingThemes,
    required this.decliningThemes,
    required this.reflectionCountThisWeek, required this.hasSufficientData, this.primaryBelief,
  });

  final DateTime weekStart;
  final DateTime weekEnd;
  final List<WeeklyThemeLine> topThemes;
  final List<WeeklyThemeLine> growingThemes;
  final List<WeeklyThemeLine> decliningThemes;
  final String? primaryBelief;
  final int reflectionCountThisWeek;
  final bool hasSufficientData;
}

class WeeklyThemeLine {
  const WeeklyThemeLine({
    required this.label,
    required this.count,
    required this.priorCount,
  });

  final String label;
  final int count;
  final int priorCount;
}