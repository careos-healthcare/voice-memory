import '../../models/journal_entry.dart';

enum ArchiveMaturityStage {
  starting,
  buildingEvidence,
  beliefsForming,
  beliefsChanging,
  matureArchive,
}

class ArchiveMaturityInput {
  const ArchiveMaturityInput({
    required this.reflectionCount,
    required this.beliefCount,
    required this.beliefChanges,
    required this.reputationScore,
    required this.timelineAgeDays,
  });

  final int reflectionCount;
  final int beliefCount;
  final int beliefChanges;
  final int reputationScore;
  final int timelineAgeDays;
}

class ArchiveProgressView {
  const ArchiveProgressView({
    required this.score,
    required this.stage,
    required this.stageLabel,
    required this.headline,
    required this.nextMilestoneLabel,
    required this.nextMilestonePercent,
  });

  final int score;
  final ArchiveMaturityStage stage;
  final String stageLabel;
  final String headline;
  final String nextMilestoneLabel;
  final int nextMilestonePercent;
}

/// Unified archive maturity score (0–100) for mobile progress bar.
class ArchiveMaturityEngine {
  static const headline = 'Your archive is becoming harder to fool.';

  static const _milestones = <({int percent, String label})>[
    (percent: 20, label: 'Enough reflections to compare'),
    (percent: 40, label: 'First beliefs under review'),
    (percent: 60, label: 'Beliefs shifting with new evidence'),
    (percent: 80, label: 'Archive reputation strengthening'),
    (percent: 100, label: 'Mature archive — beliefs hard to fool'),
  ];

  static int compute(ArchiveMaturityInput input) {
    final raw =
        (input.reflectionCount.clamp(0, 15) * 3.2) +
        (input.beliefCount.clamp(0, 8) * 5.5) +
        (input.beliefChanges.clamp(0, 12) * 4) +
        (input.reputationScore.clamp(0, 100) * 0.28) +
        (input.timelineAgeDays.clamp(0, 120) * 0.12);
    return raw.round().clamp(0, 100);
  }

  static ArchiveMaturityStage stageFor({
    required int reflectionCount,
    required int beliefCount,
    required int beliefChanges,
    required int score,
  }) {
    if (reflectionCount <= 1) return ArchiveMaturityStage.starting;
    if (reflectionCount <= 3 && beliefCount == 0) {
      return ArchiveMaturityStage.buildingEvidence;
    }
    if (beliefCount == 0) return ArchiveMaturityStage.buildingEvidence;
    if (beliefChanges >= 2 || score >= 72) {
      return ArchiveMaturityStage.matureArchive;
    }
    if (beliefChanges >= 1 || score >= 48) {
      return ArchiveMaturityStage.beliefsChanging;
    }
    return ArchiveMaturityStage.beliefsForming;
  }

  static String stageLabel(ArchiveMaturityStage stage) {
    switch (stage) {
      case ArchiveMaturityStage.starting:
        return 'Starting';
      case ArchiveMaturityStage.buildingEvidence:
        return 'Building evidence';
      case ArchiveMaturityStage.beliefsForming:
        return 'Beliefs forming';
      case ArchiveMaturityStage.beliefsChanging:
        return 'Beliefs changing';
      case ArchiveMaturityStage.matureArchive:
        return 'Mature archive';
    }
  }

  static ({String label, int percent}) nextMilestone(int score) {
    for (final m in _milestones) {
      if (m.percent > score) return (label: m.label, percent: m.percent);
    }
    return _milestones.last;
  }

  static ArchiveProgressView buildView(ArchiveMaturityInput input) {
    final score = compute(input);
    final stage = stageFor(
      reflectionCount: input.reflectionCount,
      beliefCount: input.beliefCount,
      beliefChanges: input.beliefChanges,
      score: score,
    );
    final milestone = nextMilestone(score);
    return ArchiveProgressView(
      score: score,
      stage: stage,
      stageLabel: stageLabel(stage),
      headline: headline,
      nextMilestoneLabel: milestone.label,
      nextMilestonePercent: milestone.percent,
    );
  }

  static ArchiveMaturityInput inputFromEntries(List<JournalEntry> entries) {
    final eligible = entries
        .where((e) => e.transcript.trim().isNotEmpty)
        .toList();
    eligible.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final reflectionCount = eligible.length;
    final beliefCount = reflectionCount >= 5 ? 1 : 0;
    final beliefChanges = reflectionCount >= 6 ? 1 : 0;

    int timelineDays = 0;
    if (eligible.isNotEmpty) {
      timelineDays =
          eligible.last.createdAt
              .difference(eligible.first.createdAt)
              .inDays
              .abs() +
          1;
    }

    final reputationScore = (reflectionCount * 8 + timelineDays).clamp(0, 100);

    return ArchiveMaturityInput(
      reflectionCount: reflectionCount,
      beliefCount: beliefCount,
      beliefChanges: beliefChanges,
      reputationScore: reputationScore,
      timelineAgeDays: timelineDays,
    );
  }
}
