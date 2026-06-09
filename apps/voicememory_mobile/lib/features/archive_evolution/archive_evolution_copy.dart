import 'archive_evolution_models.dart';

/// Section headlines and example bodies for evolution events.
abstract final class ArchiveEvolutionCopy {
  ArchiveEvolutionCopy._();

  static const String archiveQuestion = 'WHAT HAS MY ARCHIVE LEARNED?';

  static const String updatingMessage = 'The archive is updating…';

  static String sectionHeadlineFor(ArchiveEvolutionKind kind) {
    return switch (kind) {
      ArchiveEvolutionKind.archiveChangedMind =>
        'YOUR ARCHIVE CHANGED ITS MIND',
      ArchiveEvolutionKind.confidenceIncreased =>
        'YOUR ARCHIVE BECAME MORE CERTAIN',
      ArchiveEvolutionKind.confidenceDecreased =>
        'YOUR ARCHIVE IS QUESTIONING THIS',
      ArchiveEvolutionKind.beliefUnderReview =>
        'YOUR ARCHIVE IS QUESTIONING THIS',
      ArchiveEvolutionKind.newPatternEmerging =>
        'YOUR ARCHIVE NOTICED SOMETHING NEW',
      ArchiveEvolutionKind.oldPatternFading =>
        'YOUR ARCHIVE NOTICED SOMETHING NEW',
    };
  }

  static String lastArchiveUpdateLabel(DateTime? lastActivity) {
    if (lastActivity == null) return 'Last archive update: not yet';
    final now = DateTime.now();
    final local = lastActivity.toLocal();
    final diff = now.difference(local);
    if (diff.inDays == 0) {
      if (diff.inHours < 1) return 'Last archive update: just now';
      return 'Last archive update: today';
    }
    if (diff.inDays == 1) return 'Last archive update: 1 day ago';
    return 'Last archive update: ${diff.inDays} days ago';
  }
}
