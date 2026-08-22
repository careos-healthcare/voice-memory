/// How strongly a user's archive appears to relate to what they are working
/// on right now.
///
/// Memory should be evidence, not gravity: the archive may only speak up
/// when there is genuine, engine-backed evidence — and the user can always
/// decline the connection.
enum MemoryRelevance {
  /// Not enough evidence to connect anything. No archive-based
  /// interpretation is shown.
  fresh,

  /// Only one loose signal. Major memory cards are not shown.
  weak,

  /// Two or more safe signals, but not enough to claim a return.
  /// Cautious wording only.
  possible,

  /// An existing evidence engine already supports thread-return evidence.
  /// This is the only level allowed to use confident comparison language.
  strong,
}

/// Stable analytics id for a [MemoryRelevance] level.
extension MemoryRelevanceId on MemoryRelevance {
  String get id {
    switch (this) {
      case MemoryRelevance.fresh:
        return 'fresh';
      case MemoryRelevance.weak:
        return 'weak';
      case MemoryRelevance.possible:
        return 'possible';
      case MemoryRelevance.strong:
        return 'strong';
    }
  }
}

/// The gate's read on the archive right now. Counts and a level only —
/// never user text.
class MemoryRelevanceAssessment {
  const MemoryRelevanceAssessment({
    required this.relevance,
    required this.signalCount,
    required this.entryCount,
  });

  final MemoryRelevance relevance;

  /// Number of loose connection signals found (repeated context id,
  /// repeated option id, repeated free-text word, recent density).
  final int signalCount;

  final int entryCount;
}