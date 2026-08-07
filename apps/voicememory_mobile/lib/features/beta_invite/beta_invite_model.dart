/// Surfaces where the beta invite loop card can appear.
enum BetaInviteLoopSurface { recordPostSave, archivePatterns, testing }

extension BetaInviteLoopSurfaceAnalytics on BetaInviteLoopSurface {
  String get analyticsValue => switch (this) {
    BetaInviteLoopSurface.recordPostSave => 'record_post_save',
    BetaInviteLoopSurface.archivePatterns => 'archive_patterns',
    BetaInviteLoopSurface.testing => 'testing',
  };
}

/// Why the beta invite loop became eligible.
enum BetaInviteLoopTrigger { usefulFeedback, strongProof }

extension BetaInviteLoopTriggerAnalytics on BetaInviteLoopTrigger {
  String get analyticsValue => switch (this) {
    BetaInviteLoopTrigger.usefulFeedback => 'useful_feedback',
    BetaInviteLoopTrigger.strongProof => 'strong_proof',
  };
}

class BetaInviteLoopContext {
  const BetaInviteLoopContext({
    required this.surface,
    required this.source,
    required this.entryCount,
    required this.betaMissionEnabled,
    required this.dismissed,
    required this.hasFirstProof,
    required this.trigger,
    this.isRecording = false,
    this.isDegradedTranscriptState = false,
    this.isPostSaveDegradedState = false,
    this.whatChangedQuestionActive = false,
    this.patternReviewInboxHasActiveItems = false,
  });

  final BetaInviteLoopSurface surface;
  final String source;
  final int entryCount;
  final bool betaMissionEnabled;
  final bool dismissed;
  final bool hasFirstProof;
  final BetaInviteLoopTrigger? trigger;
  final bool isRecording;
  final bool isDegradedTranscriptState;
  final bool isPostSaveDegradedState;
  final bool whatChangedQuestionActive;
  final bool patternReviewInboxHasActiveItems;
}

class BetaInviteLoopResult {
  const BetaInviteLoopResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.cta,
    required this.secondary,
    required this.inviteText,
    required this.source,
    required this.surface,
    required this.entryCount,
    required this.trigger,
  });

  final bool shouldShow;
  final String title;
  final String body;
  final String cta;
  final String secondary;
  final String inviteText;
  final String source;
  final BetaInviteLoopSurface surface;
  final int entryCount;
  final BetaInviteLoopTrigger? trigger;
}
