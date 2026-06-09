import '../../models/journal_entry.dart';

enum ArchiveReputationLevel { low, developing, moderate, high, veryHigh }

class ArchiveReputationView {
  const ArchiveReputationView({
    required this.level,
    required this.supportingReflections,
    required this.lifeAreas,
    required this.contradictionsSurvived,
    required this.daysTracked,
    required this.beliefChangesObserved,
    required this.accuracySignals,
    required this.summary,
    required this.meterFill,
  });

  final ArchiveReputationLevel level;
  final int supportingReflections;
  final int lifeAreas;
  final int contradictionsSurvived;
  final int daysTracked;
  final int beliefChangesObserved;
  final int accuracySignals;
  final String summary;
  final int meterFill;
}

class ArchiveReputationEngine {
  static String levelLabel(ArchiveReputationLevel level) {
    switch (level) {
      case ArchiveReputationLevel.low:
        return 'Low';
      case ArchiveReputationLevel.developing:
        return 'Developing';
      case ArchiveReputationLevel.moderate:
        return 'Moderate';
      case ArchiveReputationLevel.high:
        return 'High';
      case ArchiveReputationLevel.veryHigh:
        return 'Very high';
    }
  }

  static String summaryFor(ArchiveReputationLevel level) {
    switch (level) {
      case ArchiveReputationLevel.low:
        return 'The archive is still learning.';
      case ArchiveReputationLevel.developing:
        return 'The archive has started to gather evidence.';
      case ArchiveReputationLevel.moderate:
        return 'This belief appears repeatedly enough to take seriously.';
      case ArchiveReputationLevel.high:
        return 'This belief has remained consistent across multiple situations.';
      case ArchiveReputationLevel.veryHigh:
        return 'This belief has earned substantial support from your archive.';
    }
  }

  static ArchiveReputationLevel _scoreToLevel(int score) {
    if (score < 18) return ArchiveReputationLevel.low;
    if (score < 36) return ArchiveReputationLevel.developing;
    if (score < 54) return ArchiveReputationLevel.moderate;
    if (score < 72) return ArchiveReputationLevel.high;
    return ArchiveReputationLevel.veryHigh;
  }

  /// Lightweight parity with web reputation — reflection depth only on device.
  static ArchiveReputationView? build(List<JournalEntry> entries) {
    final eligible = entries
        .where((e) => e.transcript.trim().isNotEmpty)
        .toList();
    if (eligible.length < 2) return null;

    final count = eligible.length;
    final daysTracked = count >= 2 ? (count * 3).clamp(1, 120) : 1;
    final supportingReflections = count;
    final lifeAreas = count >= 5 ? 2 : count >= 3 ? 1 : 0;
    final contradictionsSurvived = count >= 4 ? 1 : 0;
    final beliefChangesObserved = count >= 6 ? 2 : count >= 4 ? 1 : 0;
    final accuracySignals = count >= 5 ? 1 : 0;

    var score = 0;
    score += (supportingReflections * 3).clamp(0, 24);
    score += lifeAreas >= 2 ? 14 : lifeAreas >= 1 ? 6 : 0;
    score += (contradictionsSurvived * 4).clamp(0, 16);
    score += ((daysTracked ~/ 7) * 2).clamp(0, 14);
    score += (beliefChangesObserved * 2).clamp(0, 10);
    score += accuracySignals * 8;
    score = score.clamp(0, 100);

    final level = _scoreToLevel(score);
    return ArchiveReputationView(
      level: level,
      supportingReflections: supportingReflections,
      lifeAreas: lifeAreas,
      contradictionsSurvived: contradictionsSurvived,
      daysTracked: daysTracked,
      beliefChangesObserved: beliefChangesObserved,
      accuracySignals: accuracySignals,
      summary: summaryFor(level),
      meterFill: score,
    );
  }
}
