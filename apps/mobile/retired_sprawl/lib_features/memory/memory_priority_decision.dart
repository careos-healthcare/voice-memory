import 'package:archiveme_mobile/features/memory/memory_control_model.dart';

/// Priority band — how much influence archive evidence may carry.
enum MemoryPriorityBand {
  suppressed('suppressed'),
  background('background'),
  normal('normal'),
  important('important'),
  essential('essential');

  const MemoryPriorityBand(this.id);

  final String id;

  bool get canSupportMajorClaim =>
      this == MemoryPriorityBand.normal ||
      this == MemoryPriorityBand.important ||
      this == MemoryPriorityBand.essential;
}

/// Stable priority decision ids — safe for analytics.
abstract class MemoryPriorityDecisionId {
  MemoryPriorityDecisionId._();

  static const String suppressedFresh = 'suppressed_fresh';
  static const String suppressedKeepSeparate = 'suppressed_keep_separate';
  static const String suppressedNotRelated = 'suppressed_not_related';
  static const String suppressedWrongThread = 'suppressed_wrong_thread';
  static const String suppressedWrongPack = 'suppressed_wrong_pack';
  static const String suppressedNotImportant = 'suppressed_not_important';
  static const String backgroundOldOneOff = 'background_old_one_off';
  static const String backgroundStale = 'background_stale';
  static const String backgroundMixed = 'background_mixed';
  static const String normalRecentRelated = 'normal_recent_related';
  static const String importantRepeated = 'important_repeated';
  static const String importantSameThread = 'important_same_thread';
  static const String importantSamePack = 'important_same_pack';
  static const String importantPinned = 'important_pinned';
  static const String importantExact = 'important_exact';
  static const String essentialUserConfirmed = 'essential_user_confirmed';
  static const String essentialCurrentEntry = 'essential_current_entry';
}

/// Stable reason ids for priority explanations and analytics.
abstract class MemoryPriorityReasonId {
  MemoryPriorityReasonId._();

  static const String currentEntry = 'current_entry';
  static const String userConfirmed = 'user_confirmed';
  static const String sameThread = 'same_thread';
  static const String samePack = 'same_pack';
  static const String repeatedEvidence = 'repeated_evidence';
  static const String recentEvidence = 'recent_evidence';
  static const String pinnedEvidence = 'pinned_evidence';
  static const String exactEvidence = 'exact_evidence';
  static const String oldOneOff = 'old_one_off';
  static const String staleEvidence = 'stale_evidence';
  static const String mixedEvidence = 'mixed_evidence';
  static const String wrongThread = 'wrong_thread';
  static const String wrongPack = 'wrong_pack';
  static const String notRelated = 'not_related';
  static const String notImportant = 'not_important';
  static const String freshEntry = 'fresh_entry';
  static const String keepSeparate = 'keep_separate';
}

/// Safe explanation ids for consumer-facing copy — no private text.
abstract class MemoryPriorityExplanationId {
  MemoryPriorityExplanationId._();

  static const String sameThread = 'same_thread';
  static const String samePack = 'same_pack';
  static const String repeated = 'repeated';
  static const String userConfirmed = 'user_confirmed';
  static const String pinned = 'pinned';
  static const String exact = 'exact';
  static const String oldOneOffBackground = 'old_one_off_background';
  static const String mixedCautious = 'mixed_cautious';
  static const String notImportantDemoted = 'not_important_demoted';
  static const String recentRelated = 'recent_related';
}

/// Result of priority governance for one memory card.
class MemoryPriorityDecision {
  const MemoryPriorityDecision({
    required this.priorityBand,
    required this.decisionId,
    required this.reasonIds,
    required this.shouldSuppress,
    required this.backgroundOnly,
    required this.canSupportClaim,
    required this.canOutrankCurrentContext,
    required this.safeExplanationId,
  });

  final MemoryPriorityBand priorityBand;
  final String decisionId;
  final List<String> reasonIds;
  final bool shouldSuppress;
  final bool backgroundOnly;
  final bool canSupportClaim;
  final bool canOutrankCurrentContext;
  final String safeExplanationId;
}

/// Consumer copy for priority explanations — compile-time constants only.
abstract class MemoryPriorityCopy {
  MemoryPriorityCopy._();

  static const String notImportantLabel = 'Not important';
  static const String notImportantThanks =
      'Thanks — ArchiveMe will give this less weight.';
  static const String moreActionsLabel = 'More';

  static const String explainSameThread =
      'Used because it belongs to this thread.';
  static const String explainSamePack = 'Used because it belongs to this pack.';
  static const String explainRepeated =
      'Used because it appeared more than once.';
  static const String explainUserConfirmed = 'Used because you confirmed it.';
  static const String explainPinned = 'Used because you pinned it.';
  static const String explainExact =
      'Used because you marked it as exact evidence.';
  static const String explainOldOneOffBackground =
      'Older one-off evidence was kept in the background.';
  static const String explainMixedCautious =
      'Mixed evidence was treated cautiously.';
  static const String explainNotImportantDemoted =
      'You marked this as less important.';
  static const String explainRecentRelated =
      'Used because it is recent and related.';

  static String explanationFor(String safeExplanationId) =>
      switch (safeExplanationId) {
        MemoryPriorityExplanationId.sameThread => explainSameThread,
        MemoryPriorityExplanationId.samePack => explainSamePack,
        MemoryPriorityExplanationId.repeated => explainRepeated,
        MemoryPriorityExplanationId.userConfirmed => explainUserConfirmed,
        MemoryPriorityExplanationId.pinned => explainPinned,
        MemoryPriorityExplanationId.exact => explainExact,
        MemoryPriorityExplanationId.oldOneOffBackground =>
          explainOldOneOffBackground,
        MemoryPriorityExplanationId.mixedCautious => explainMixedCautious,
        MemoryPriorityExplanationId.notImportantDemoted =>
          explainNotImportantDemoted,
        MemoryPriorityExplanationId.recentRelated => explainRecentRelated,
        _ => MemoryControlCopy.whyBodyShared,
      };

  static const List<String> all = [
    notImportantLabel,
    notImportantThanks,
    moreActionsLabel,
    explainSameThread,
    explainSamePack,
    explainRepeated,
    explainUserConfirmed,
    explainPinned,
    explainExact,
    explainOldOneOffBackground,
    explainMixedCautious,
    explainNotImportantDemoted,
    explainRecentRelated,
  ];
}