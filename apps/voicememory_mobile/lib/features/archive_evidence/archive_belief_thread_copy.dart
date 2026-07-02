/// Consumer copy for the archive belief differentiation layer.
abstract class ArchiveBeliefThreadCopy {
  ArchiveBeliefThreadCopy._();

  static const String threadTitle =
      'Your archive is starting to show repeated evidence.';
  static const String currentBeliefLabel = 'What this may be pointing to';
  static const String evidenceLabel = 'Evidence';
  static const String whatChangedLabel = 'What changed';
  static const String whatToTestLabel = 'What ArchiveMe is watching next';

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

  static const String proKeepsThread = 'Keep the full archive';
  static const String proNearbyTitle = 'Keep the full archive';
  static const String fullArchiveHistoryTitle = 'Keep the full archive';
  static const String fullArchiveHistoryBody =
      'Your first repeat is free. Pro keeps the evidence history from your own '
      'words — not conversation history — so ArchiveMe can show whether patterns '
      'get stronger, softer, or change over time.';
  static const List<String> fullArchiveHistoryBullets = [
    'Full evidence history',
    'Pattern change tracking',
    'Weekly archive reviews',
    'Private archive reports',
  ];
  static const String freeShowsFirstRepeat = 'Free shows the first repeat.';
  static const String proKeepsTimeline = 'Pro keeps the timeline of what changed.';
  static const String proComparesReturns =
      'Pro lets ArchiveMe compare returns over time.';
  static const String whyPro =
      'The value is not one answer. It is the evidence trail over time.';
  static const String proDeeperHistory =
      'Pro keeps the full evidence history so ArchiveMe can compare returns over time.';
  static const String proReviewChanges =
      'Pro keeps the timeline of what changed across your archive.';
  static const String proBridgeBody =
      'Your first repeat is free. Pro keeps the evidence history so ArchiveMe '
      'can show whether patterns get stronger, softer, or change over time.';
  static const String proNearbyBridgeBody =
      'Free shows the first repeat. Pro keeps the timeline of what changed.';
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
  static const String weeklyWhatToTestNext = 'What ArchiveMe is watching next';
  static const String weeklyProContinuity =
      'Pro keeps weekly archive reviews so ArchiveMe can compare what repeated '
      'and changed over time.';

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
    proNearbyTitle,
    fullArchiveHistoryTitle,
    fullArchiveHistoryBody,
    ...fullArchiveHistoryBullets,
    freeShowsFirstRepeat,
    proKeepsTimeline,
    proComparesReturns,
    whyPro,
    proDeeperHistory,
    proReviewChanges,
    proBridgeBody,
    proNearbyBridgeBody,
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
