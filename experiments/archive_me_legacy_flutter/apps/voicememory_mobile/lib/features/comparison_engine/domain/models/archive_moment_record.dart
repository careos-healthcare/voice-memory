enum PatternState {
  earlySignal,
  possibleRepeat,
  clearRepeat,
  stillCurrent,
  fading,
  changed,
  softened,
  corrected,
  notEnoughEvidence,
}

class ArchiveMomentRecord {
  final String id;
  final DateTime createdAt;

  /// The raw, unfiltered text or transcribed voice words of the user.
  final String savedWords;

  /// Optional ID linking this moment to an existing recurring pattern thread.
  final String? parentThreadId;

  /// The current cautious pattern label assigned by the comparison engine.
  final PatternState alignmentState;

  const ArchiveMomentRecord({
    required this.id,
    required this.createdAt,
    required this.savedWords,
    this.parentThreadId,
    this.alignmentState = PatternState.earlySignal,
  });

  /// Factory to instantiate a brand new single moment.
  factory ArchiveMomentRecord.capture(
    String words, {
    String? connectingThreadId,
  }) {
    return ArchiveMomentRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      savedWords: words,
      parentThreadId: connectingThreadId,
      alignmentState: connectingThreadId == null
          ? PatternState.earlySignal
          : PatternState.possibleRepeat,
    );
  }
}
