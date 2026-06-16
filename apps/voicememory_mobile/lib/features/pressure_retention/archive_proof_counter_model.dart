/// Compact proof that the archive is accumulating evidence over time:
/// how many recordings are connected, how often the thread returned, and
/// whether there is enough evidence to compare tomorrow.
///
/// Every count maps to real saved entries — nothing is fabricated, and no
/// line implies obligation, streaks, or resolution.
class ArchiveProofCounter {
  const ArchiveProofCounter({
    required this.hasProof,
    this.connectedLine = '',
    this.threadReturnLine = '',
    this.readinessLine = '',
    this.onePieceLine = '',
    this.connectedCount = 0,
    this.threadReturnCount = 0,
    this.entryIds = const [],
  });

  /// Connected-count lines need at least this many thread-connected entries.
  static const int minConnectedEntries = 2;

  /// Shown once a thread genuinely repeated — there is now something real to
  /// compare against tomorrow. An observation, never an assignment.
  static const String enoughEvidenceLine =
      'ArchiveMe now has enough evidence to compare tomorrow.';

  /// Post-save acknowledgement: one more piece of evidence exists. No streak,
  /// no demand to continue.
  static const String onePieceTodayLine = 'You added one more piece today.';

  /// False when the archive holds no meaningful evidence to count yet.
  final bool hasProof;

  /// e.g. "Your archive has 3 connected recordings." Empty when no thread
  /// connects the entries — a raw total would overclaim connection.
  final String connectedLine;

  /// e.g. "This thread has returned 2 times." Empty without a repeated thread.
  final String threadReturnLine;

  /// [enoughEvidenceLine] when a thread repeated; empty otherwise.
  final String readinessLine;

  /// [onePieceTodayLine] right after a successful save; empty otherwise.
  final String onePieceLine;

  /// How many saved entries the connected thread spans. Always matches
  /// [entryIds].length — counts are never fabricated.
  final int connectedCount;

  /// How many times the thread came back after its first appearance.
  final int threadReturnCount;

  /// The exact entries behind the counts.
  final List<String> entryIds;

  factory ArchiveProofCounter.none() =>
      const ArchiveProofCounter(hasProof: false);
}
