import '../../config/app_config.dart';
import '../../models/journal_entry.dart';

enum ArchiveValueStage {
  oneDataPoint,
  possibleRepeat,
  patternForming,
  theoryUnderReview,
  patternReviewUnlocked,
}

class ArchiveValueSnapshot {
  const ArchiveValueSnapshot({
    required this.reflectionCount,
    required this.stage,
    required this.valueCopy,
    required this.nextMilestoneCopy,
    required this.progressPercent,
    required this.readyForPatternReview,
    required this.ctaLabel,
    required this.ctaRoute,
  });

  final int reflectionCount;
  final ArchiveValueStage stage;
  final String valueCopy;
  final String nextMilestoneCopy;
  final int progressPercent;
  final bool readyForPatternReview;
  final String ctaLabel;
  final String ctaRoute;
}

class ArchiveValueProgress {
  static const target = AppConfig.patternReviewReflectionTarget;

  static ArchiveValueStage stageForCount(int count) {
    if (count <= 1) return ArchiveValueStage.oneDataPoint;
    if (count == 2) return ArchiveValueStage.possibleRepeat;
    if (count == 3) return ArchiveValueStage.patternForming;
    if (count == 4) return ArchiveValueStage.theoryUnderReview;
    return ArchiveValueStage.patternReviewUnlocked;
  }

  static String valueCopyForStage(ArchiveValueStage stage) {
    switch (stage) {
      case ArchiveValueStage.oneDataPoint:
        return 'One data point saved.';
      case ArchiveValueStage.possibleRepeat:
        return 'ArchiveMe can now check for possible repeats.';
      case ArchiveValueStage.patternForming:
        return 'Patterns may be starting to form.';
      case ArchiveValueStage.theoryUnderReview:
        return 'A theory is under review.';
      case ArchiveValueStage.patternReviewUnlocked:
        return 'Your first evidence-based pattern review is unlocked.';
    }
  }

  static String nextMilestoneCopy(int count) {
    if (count >= target) return 'Open your pattern review.';
    if (count >= 3) return '1 more moment until your first pattern review.';
    if (count >= 1) {
      return '1 more moment until ArchiveMe can compare this properly.';
    }
    return 'Save one real moment.';
  }

  static ArchiveValueSnapshot build(List<JournalEntry> entries) {
    final eligible = entries
        .where((e) => e.transcript.trim().isNotEmpty)
        .toList();
    final count = eligible.length;
    final stage = stageForCount(count);
    final ready = count >= target;
    final progressPercent = ((count.clamp(0, target) / target) * 100).round();
    return ArchiveValueSnapshot(
      reflectionCount: count,
      stage: stage,
      valueCopy: valueCopyForStage(stage),
      nextMilestoneCopy: nextMilestoneCopy(count),
      progressPercent: progressPercent,
      readyForPatternReview: ready,
      ctaLabel: ready ? 'Open pattern review' : 'Record another moment',
      ctaRoute: ready ? '/self-discovery?tab=blind-spots' : '/record',
    );
  }

  static String archiveChangedMessage(List<JournalEntry> entries) {
    final snapshot = build(entries);
    return 'Your archive now has ${snapshot.reflectionCount} saved moment'
        '${snapshot.reflectionCount == 1 ? '' : 's'}. '
        '${snapshot.valueCopy} ${snapshot.nextMilestoneCopy}';
  }
}
