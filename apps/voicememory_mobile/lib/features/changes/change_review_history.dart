import 'change_thread_correction.dart';

/// One dated line in a thread's review history.
///
/// The history is derived from the append-only correction log, so it records
/// what the user actually did rather than a summary ArchiveMe wrote later.
class ChangeReviewEntry {
  const ChangeReviewEntry({required this.at, required this.description});

  final DateTime at;
  final String description;
}

abstract final class ChangeReviewHistory {
  ChangeReviewHistory._();

  /// The corrections that touched [threadId], oldest first.
  ///
  /// A merge is listed on both sides: the thread that was folded in and the
  /// thread that absorbed it both changed, and hiding one half would make the
  /// surviving thread's history look like it grew on its own.
  static List<ChangeReviewEntry> forThread(
    String threadId,
    Iterable<ChangeThreadCorrection> corrections,
  ) {
    final ordered = corrections.toList()..sort((a, b) => a.at.compareTo(b.at));
    final history = <ChangeReviewEntry>[];
    for (final correction in ordered) {
      final description = _describe(correction, threadId);
      if (description == null) continue;
      history.add(
        ChangeReviewEntry(at: correction.at, description: description),
      );
    }
    return List.unmodifiable(history);
  }

  static String? _describe(ChangeThreadCorrection correction, String threadId) {
    switch (correction) {
      case RenameChangeThread():
        return correction.threadId == threadId
            ? 'You renamed this thread.'
            : null;
      case SplitChangeThread():
        return correction.threadId == threadId
            ? 'You moved some moments out of this thread.'
            : null;
      case MergeChangeThreads(:final intoThreadId):
        if (correction.threadId == threadId) {
          return 'You merged this thread into another one.';
        }
        return intoThreadId == threadId
            ? 'You merged another thread into this one.'
            : null;
      case SuppressChangeThreadFraming(:final eventId):
        if (correction.threadId != threadId) return null;
        return eventId == null
            ? 'You hid this reading.'
            : 'You hid one reading in this thread.';
    }
  }
}
