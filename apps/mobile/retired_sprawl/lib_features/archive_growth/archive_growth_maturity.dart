/// Recording-count maturity levels (Growth Loop V1).
enum ArchiveGrowthLevel { seed, growing, established, insightful, historian }

class ArchiveGrowthMaturity {
  const ArchiveGrowthMaturity({
    required this.level,
    required this.label,
    required this.recordingCount,
    required this.nextLevel,
    required this.recordingsUntilNext,
    required this.nextLevelLabel,
  });

  final ArchiveGrowthLevel level;
  final String label;
  final int recordingCount;
  final ArchiveGrowthLevel? nextLevel;
  final int recordingsUntilNext;
  final String? nextLevelLabel;

  static ArchiveGrowthMaturity fromRecordingCount(int count) {
    final n = count.clamp(0, 10000);
    if (n >= 200) {
      return ArchiveGrowthMaturity(
        level: ArchiveGrowthLevel.historian,
        label: 'Historian',
        recordingCount: n,
        nextLevel: null,
        recordingsUntilNext: 0,
        nextLevelLabel: null,
      );
    }
    if (n >= 100) {
      return ArchiveGrowthMaturity(
        level: ArchiveGrowthLevel.insightful,
        label: 'Insightful',
        recordingCount: n,
        nextLevel: ArchiveGrowthLevel.historian,
        recordingsUntilNext: 200 - n,
        nextLevelLabel: 'Historian',
      );
    }
    if (n >= 50) {
      return ArchiveGrowthMaturity(
        level: ArchiveGrowthLevel.established,
        label: 'Established',
        recordingCount: n,
        nextLevel: ArchiveGrowthLevel.insightful,
        recordingsUntilNext: 100 - n,
        nextLevelLabel: 'Insightful',
      );
    }
    if (n >= 10) {
      return ArchiveGrowthMaturity(
        level: ArchiveGrowthLevel.growing,
        label: 'Growing',
        recordingCount: n,
        nextLevel: ArchiveGrowthLevel.established,
        recordingsUntilNext: 50 - n,
        nextLevelLabel: 'Established',
      );
    }
    return ArchiveGrowthMaturity(
      level: ArchiveGrowthLevel.seed,
      label: 'Seed',
      recordingCount: n,
      nextLevel: ArchiveGrowthLevel.growing,
      recordingsUntilNext: (10 - n).clamp(1, 10),
      nextLevelLabel: 'Growing',
    );
  }
}