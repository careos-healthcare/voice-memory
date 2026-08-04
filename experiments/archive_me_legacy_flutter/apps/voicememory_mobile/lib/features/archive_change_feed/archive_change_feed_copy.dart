/// User-facing Archive Change Feed strings.
abstract class ArchiveChangeFeedCopy {
  ArchiveChangeFeedCopy._();

  static const String sectionTitle = 'What Changed Since Last Review';

  static const String noBaseline =
      'Your next archive review will show what changed — evidence counts and mention trends.';

  static const String noChanges =
      'No measurable shifts in beliefs, contradictions, or themes since your last review.';

  static const String beliefsStrengthenedTitle = 'Beliefs strengthened';
  static const String beliefsWeakenedTitle = 'Beliefs weakened';
  static const String contradictionsAppearedTitle = 'Contradictions appeared';
  static const String contradictionsResolvedTitle = 'Contradictions resolved';
  static const String themesIncreasingTitle = 'Themes increasing';
  static const String themesDecreasingTitle = 'Themes decreasing';

  static const String mentionsLabel = 'mentions';
  static const String evidenceLabel = 'Evidence';
  static const String counterEvidenceLabel = 'Counter-evidence';
  static const String confidenceLabel = 'Confidence';
  static const String newReflectionsLabel = 'New saved moments since review';

  static String mentionTrendLabel(List<int> series) {
    if (series.isEmpty) return '0 mentions';
    if (series.length == 1) return '${series.first} mentions';
    return '${series.join(' → ')} mentions';
  }
}
