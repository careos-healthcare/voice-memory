/// Consumer copy for the archive belief differentiation layer.
abstract class ArchiveBeliefThreadCopy {
  ArchiveBeliefThreadCopy._();

  static const String threadTitle =
      'Your archive is starting to show a thread.';
  static const String currentBeliefLabel = 'What this may be pointing to';
  static const String evidenceLabel = 'Evidence';
  static const String whatChangedLabel = 'What changed';
  static const String whatToTestLabel = 'What to test';

  static const String timelineTitle = 'This thread over time';
  static const String timelineFirstAppeared = 'First appeared';
  static const String timelineReturned = 'Returned';
  static const String timelineChanged = 'Changed';
  static const String timelineWhatFaded = 'What faded';
  static const String timelineCurrentSignal = 'Current signal';
  static const String timelineCurrentSignalBody = 'Still worth watching';

  static const String worthWatching = 'This may be worth watching.';
  static const String previousBeliefLabel = 'Earlier thread';
  static const String nowBeliefLabel = 'Now it is starting to point toward';
  static const String whatReturnedLabel = 'What returned';
  static const String whatFadedLabel = 'What faded';
  static const String supportingEvidenceLabel = 'Supporting evidence';
  static const String confidenceLabel = 'Signal strength';

  static const String proKeepsThread =
      'Pro keeps the thread connected over time.';
  static const String proDeeperHistory =
      'See deeper history and saved evidence.';
  static const String proReviewChanges =
      'Review how this changed across your archive.';
  static const String proBridgeBody =
      "Free shows today's thread. Pro keeps the deeper history connected.";
  static const String proBridgeCta = 'See Pro';
  static const String proBridgeSecondary = 'Not now';

  static const String saveThread = 'Save this thread';
  static const String notMe = 'Not me';
  static const String closeButDifferent = 'Close, but different';
  static const String recordMoreEvidence = 'Record more evidence';

  static const String saveThreadThanks =
      'Saved. ArchiveMe will keep watching this thread.';
  static const String notMeThanks =
      'Thanks — ArchiveMe will treat this as separate.';
  static const String closeThanks =
      'Thanks — that helps ArchiveMe stay closer next time.';

  static const String weeklyTitle = "This week, here's what changed.";
  static const String weeklyWhatKeptReturning = 'What kept returning';
  static const String weeklyWhatChanged = 'What changed';
  static const String weeklyWhatToTestNext = 'What to test next';
  static const String weeklyProContinuity =
      'Keep weekly reviews and deeper history over time.';

  static const String entryStarterRepeated = 'Something repeated';
  static const String entryStarterChanged = 'Something changed';
  static const String entryStarterAvoided = 'Something I avoided';

  static const String trustTitle = 'Your archive is private.';
  static const String trustDelete = 'You can delete entries.';
  static const String trustControl = 'You control what gets saved.';
  static const String trustNotTherapy =
      'ArchiveMe is not therapy or diagnosis.';

  static const List<String> all = [
    threadTitle,
    currentBeliefLabel,
    evidenceLabel,
    whatChangedLabel,
    whatToTestLabel,
    timelineTitle,
    timelineFirstAppeared,
    timelineReturned,
    timelineChanged,
    timelineWhatFaded,
    timelineCurrentSignal,
    timelineCurrentSignalBody,
    worthWatching,
    previousBeliefLabel,
    nowBeliefLabel,
    whatReturnedLabel,
    whatFadedLabel,
    supportingEvidenceLabel,
    confidenceLabel,
    proKeepsThread,
    proDeeperHistory,
    proReviewChanges,
    proBridgeBody,
    proBridgeCta,
    proBridgeSecondary,
    saveThread,
    notMe,
    closeButDifferent,
    recordMoreEvidence,
    saveThreadThanks,
    notMeThanks,
    closeThanks,
    weeklyTitle,
    weeklyWhatKeptReturning,
    weeklyWhatChanged,
    weeklyWhatToTestNext,
    weeklyProContinuity,
    entryStarterRepeated,
    entryStarterChanged,
    entryStarterAvoided,
    trustTitle,
    trustDelete,
    trustControl,
    trustNotTherapy,
  ];
}
