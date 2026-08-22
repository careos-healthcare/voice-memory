/// Deterministic topic-shift outcome — no AI, no user text.
class TopicShiftDecision {
  const TopicShiftDecision({
    required this.shouldPrompt,
    required this.decisionId,
    required this.reasonId,
    required this.suggestedAction,
  });

  final bool shouldPrompt;
  final String decisionId;
  final String reasonId;
  final String suggestedAction;
}

abstract class TopicShiftDecisionId {
  TopicShiftDecisionId._();

  static const String noShift = 'no_shift';
  static const String newDirectionPossible = 'new_direction_possible';
  static const String adjacentButUnconfirmed = 'adjacent_but_unconfirmed';
  static const String differentThread = 'different_thread';
  static const String differentPack = 'different_pack';
  static const String recentContextConflict = 'recent_context_conflict';
  static const String memoryOff = 'memory_off';
}

abstract class TopicShiftReasonId {
  TopicShiftReasonId._();

  static const String sameThread = 'same_thread';
  static const String samePack = 'same_pack';
  static const String explicitUserChoice = 'explicit_user_choice';
  static const String differentThread = 'different_thread';
  static const String differentPack = 'different_pack';
  static const String lowRelevance = 'low_relevance';
  static const String freshMode = 'fresh_mode';
  static const String keepSeparate = 'keep_separate';
  static const String memoryOff = 'memory_off';
}

abstract class TopicShiftSuggestedAction {
  TopicShiftSuggestedAction._();

  static const String useArchiveContext = 'use_archive_context';
  static const String keepSeparate = 'keep_separate';
  static const String startNewThread = 'start_new_thread';
  static const String noAction = 'no_action';
}