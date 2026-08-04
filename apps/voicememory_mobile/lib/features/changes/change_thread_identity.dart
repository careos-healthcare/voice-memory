import '../explainable_conclusion/change_dimensions.dart';
import 'change_thread.dart';

/// How a candidate finding is matched to a thread the user already has.
///
/// Identity is deliberately not "the first word two moments happen to share
/// when sorted alphabetically". That rule groups "the meeting ran late" with
/// "the meeting was cancelled" and "meeting my sister for lunch" into one
/// nonsense card. Here a match needs real agreement: overlapping subject
/// markers from [ChangeDimensionReader.subjectMarkers], backed by agreement on
/// what was actually compared, or a label the user has confirmed.
abstract final class ChangeThreadIdentity {
  /// Marker overlap that stands on its own without dimension agreement.
  static const strongMarkerOverlap = 2;

  /// A single shared marker only groups when the comparison agrees too.
  static const weakMarkerOverlap = 1;

  /// How much of the narrower subject the overlap has to cover before one
  /// shared word plus an agreeing dimension is allowed to group two findings.
  /// Without this, everything that involves answering something lands on one
  /// thread because "answer" is a word two unrelated moments can both use.
  static const minimumOverlapRatio = 0.5;

  /// Finds the one thread a finding belongs to, or refuses to choose.
  ///
  /// When two threads have an equally good claim the finding is left
  /// unresolved rather than pushed into whichever one happens to sort first.
  static ChangeThreadResolution resolve({
    required Iterable<ChangeThread> threads,
    required Set<String> subjectMarkers,
    required Set<ChangeDimension> dimensions,
    Map<String, Set<ChangeDimension>> observedDimensions = const {},
  }) {
    if (subjectMarkers.isEmpty) {
      return const ChangeThreadResolution(match: null, ambiguous: false);
    }
    final matches = <ChangeThreadMatch>[];
    for (final thread in threads) {
      if (thread.visibilityState == ChangeThreadVisibility.suppressed) {
        continue;
      }
      final shared = thread.subjectRepresentation.intersection(subjectMarkers);
      if (shared.isEmpty) continue;
      final threadDimensions =
          observedDimensions[thread.threadId] ?? const <ChangeDimension>{};
      final dimensionsAgree =
          dimensions.isNotEmpty &&
          threadDimensions.intersection(dimensions).isNotEmpty;
      final userPinned =
          thread.labelIsUserConfirmed && shared.length >= weakMarkerOverlap;
      final narrower =
          thread.subjectRepresentation.length < subjectMarkers.length
          ? thread.subjectRepresentation.length
          : subjectMarkers.length;
      final overlapRatio = narrower == 0 ? 0.0 : shared.length / narrower;
      final qualifies =
          shared.length >= strongMarkerOverlap ||
          userPinned ||
          (dimensionsAgree && overlapRatio >= minimumOverlapRatio);
      if (!qualifies) continue;
      matches.add(
        ChangeThreadMatch(
          threadId: thread.threadId,
          sharedMarkers: shared,
          dimensionsAgree: dimensionsAgree,
          userPinned: userPinned,
          firstObservedAt: thread.firstObservedAt,
        ),
      );
    }
    if (matches.isEmpty) {
      return const ChangeThreadResolution(match: null, ambiguous: false);
    }
    matches.sort(_byStrength);
    if (matches.length > 1 && _byStrength(matches[0], matches[1]) == 0) {
      return ChangeThreadResolution(match: matches.first, ambiguous: true);
    }
    return ChangeThreadResolution(match: matches.first, ambiguous: false);
  }

  /// A stable id derived from the whole marker set, so two archives that
  /// arrive at the same subject by different routes still land on one thread
  /// and a restart never renames anything.
  static String mint(Set<String> subjectMarkers) {
    final ordered = subjectMarkers.toList()..sort();
    var hash = 0x811c9dc5;
    for (final code in ordered.join('|').codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'thread_${hash.toRadixString(16).padLeft(8, '0')}';
  }

  /// A first label the user can immediately recognise and then rename.
  ///
  /// The most specific markers lead, because a longer content word is a
  /// narrower description of what the thread is about. Alphabetical order is
  /// only ever a tie-break, never the selector.
  static String labelFor(Set<String> subjectMarkers, {String fallback = ''}) {
    final ordered = subjectMarkers.toList()
      ..sort((a, b) {
        final byLength = b.length.compareTo(a.length);
        return byLength != 0 ? byLength : a.compareTo(b);
      });
    final chosen = ordered.take(2).toList();
    if (chosen.isEmpty) return fallback;
    final words = chosen.join(' ');
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }

  static int _byStrength(ChangeThreadMatch a, ChangeThreadMatch b) {
    final byPinned = (b.userPinned ? 1 : 0).compareTo(a.userPinned ? 1 : 0);
    if (byPinned != 0) return byPinned;
    final byShared = b.sharedMarkers.length.compareTo(a.sharedMarkers.length);
    if (byShared != 0) return byShared;
    final byDimensions = (b.dimensionsAgree ? 1 : 0).compareTo(
      a.dimensionsAgree ? 1 : 0,
    );
    if (byDimensions != 0) return byDimensions;
    // Age and id are pure tie-breaks. If two threads reach this point they
    // have an identical claim, which the caller treats as ambiguous.
    return 0;
  }
}

class ChangeThreadResolution {
  const ChangeThreadResolution({required this.match, required this.ambiguous});

  final ChangeThreadMatch? match;

  /// More than one thread has an equally good claim on this finding.
  final bool ambiguous;

  bool get isResolved => match != null && !ambiguous;
}

class ChangeThreadMatch {
  const ChangeThreadMatch({
    required this.threadId,
    required this.sharedMarkers,
    required this.dimensionsAgree,
    required this.userPinned,
    required this.firstObservedAt,
  });

  final String threadId;
  final Set<String> sharedMarkers;
  final bool dimensionsAgree;
  final bool userPinned;
  final DateTime firstObservedAt;
}
