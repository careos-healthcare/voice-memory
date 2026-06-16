/// Memory Controls — shared model and copy.
///
/// Memory should be evidence, not gravity: ArchiveMe only connects entries
/// when there is enough evidence, the user can keep an entry separate,
/// reject a suggested connection, and see why memory appeared. Nothing
/// here deletes or alters raw entries, and memory is never globally
/// disabled.
library;

/// The memory-based card surfaces a connection control can act on.
/// Stable ids only — safe for analytics.
enum MemoryCardType { threadReturn, weeklyReview, beliefDistance }

extension MemoryCardTypeId on MemoryCardType {
  String get id => switch (this) {
    MemoryCardType.threadReturn => 'thread_return',
    MemoryCardType.weeklyReview => 'weekly_review',
    MemoryCardType.beliefDistance => 'belief_distance',
  };

  /// High-level "Why this appeared" explanation. Deliberately generic:
  /// no notes, snippets, entry ids, dates, names, or private phrases.
  String get whyBody => switch (this) {
    MemoryCardType.threadReturn => MemoryControlCopy.whyBodyShared,
    MemoryCardType.weeklyReview => MemoryControlCopy.whyBodyShared,
    MemoryCardType.beliefDistance => MemoryControlCopy.whyBodyShared,
  };
}

/// All consumer copy for the memory controls — compile-time constants so
/// tests can sweep them and no private content can leak in.
abstract class MemoryControlCopy {
  MemoryControlCopy._();

  // Not related.
  static const String notRelatedLabel = 'Not related';
  static const String notRelatedThanks =
      'Thanks — ArchiveMe will treat this as separate.';

  // Why this appeared.
  static const String whyLabel = 'Why this appeared';
  static const String whyTitle = 'Why this appeared';
  static const String whyBodyThreadReturn =
      'ArchiveMe found enough evidence to compare this with earlier '
      'entries.';
  static const String whyBodyWeeklyReview =
      'ArchiveMe is comparing entries from this week with earlier '
      'evidence.';
  static const String whyBodyBeliefDistance =
      'ArchiveMe noticed that a belief-like phrase may be changing over '
      'time.';
  static const String whyFooter = MemoryControlCopy.whyCorrectionFooter;

  // Memory used indicator.
  static const String memoryUsedLabel = 'Memory used';
  static const String savedAsNewLabel = 'Saved as new';

  // Visible memory receipt.
  static const String usedArchiveContextLabel = 'Used archive context';

  // Why this appeared — safe high-level copy only.
  static const String whyBodyShared =
      'ArchiveMe compared this entry with eligible archive evidence.';
  static const String whyCorrectionFooter =
      'You can correct this connection if it does not fit.';

  // Memory connection actions.
  static const String keepConnectedLabel = 'Keep connected';
  static const String wrongThreadLabel = 'Wrong thread';
  static const String futureFreshLabel = 'Treat future entries as new';
  static const String keepConnectedThanks =
      'Marked as connected. ArchiveMe will treat this as user-confirmed '
      'evidence.';
  static const String futureFreshThanks =
      'Future entries here start as new. You can keep a connection later '
      'if it fits.';

  // Wrong thread flow.
  static const String wrongThreadTitle = 'Wrong thread?';
  static const String wrongThreadBody =
      'ArchiveMe may have connected this to the wrong thread.';
  static const String keepSeparateLabel = 'Keep separate';
  static const String chooseAnotherThreadLabel = 'Choose another thread';
  static const String wrongThreadKeepSeparateThanks =
      'Thanks — ArchiveMe will keep these separate.';

  // Cross-thread confirmation.
  static const String crossThreadTitle = 'Connect across threads?';
  static const String crossThreadBody =
      'This may relate to another thread. Connect it?';
  static const String crossThreadConnectLabel = 'Connect';
  static const String crossThreadKeepSeparateLabel = 'Keep separate';

  // Fresh next entry.
  static const String freshNextEntryLabel = 'Start next entry fresh';
  static const String freshNextEntryShortLabel = 'Fresh next entry';
  static const String freshNextEntryHelper =
      'The next entry will save without archive suggestions.';
}
