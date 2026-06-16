import 'current_intent_signal.dart';
import 'memory_reliability_check.dart';

/// Relevance band for the current-relevance gate.
enum RelevanceBand {
  none('none'),
  low('low'),
  medium('medium'),
  high('high');

  const RelevanceBand(this.id);

  final String id;
}

/// Stable governance decision ids — safe for analytics.
abstract class MemoryGovernanceDecisionId {
  MemoryGovernanceDecisionId._();

  static const String allowedSameThread = 'allowed_same_thread';
  static const String allowedSamePack = 'allowed_same_pack';
  static const String allowedUserConfirmed = 'allowed_user_confirmed';
  static const String blockedMemoryOff = 'blocked_memory_off';
  static const String blockedFirstSave = 'blocked_first_save';
  static const String blockedFreshEntry = 'blocked_fresh_entry';
  static const String blockedKeepSeparate = 'blocked_keep_separate';
  static const String blockedWrongThread = 'blocked_wrong_thread';
  static const String blockedWrongPack = 'blocked_wrong_pack';
  static const String blockedLowRelevance = 'blocked_low_relevance';
  static const String confirmCrossThread = 'confirm_cross_thread';
  static const String confirmCrossPack = 'confirm_cross_pack';
  static const String backgroundOnly = 'background_only';
}

/// Result of the memory governance check before a card renders.
class MemoryGovernanceDecision {
  const MemoryGovernanceDecision({
    required this.allowed,
    required this.decisionId,
    required this.reasonId,
    required this.currentIntent,
    required this.relevanceBand,
    required this.requiresUserConfirmation,
    this.reliability,
  });

  final bool allowed;
  final String decisionId;
  final String reasonId;
  final CurrentIntent currentIntent;
  final RelevanceBand relevanceBand;
  final bool requiresUserConfirmation;
  final MemoryReliabilityResult? reliability;

  /// A connection claim may render (receipt + claim content).
  bool get allowsMemoryClaim =>
      allowed &&
      !requiresUserConfirmation &&
      decisionId != MemoryGovernanceDecisionId.backgroundOnly;

  /// Evidence engines may build card content (confirmation gates handle the rest).
  bool get permitsEvidenceBuild =>
      allowed ||
      requiresUserConfirmation ||
      decisionId == MemoryGovernanceDecisionId.backgroundOnly;

  bool get showReceipt => allowsMemoryClaim;

  bool get showBackgroundOnly =>
      decisionId == MemoryGovernanceDecisionId.backgroundOnly;

  bool get showGovernanceNotice =>
      !allowed &&
      !requiresUserConfirmation &&
      decisionId != MemoryGovernanceDecisionId.blockedMemoryOff &&
      decisionId != MemoryGovernanceDecisionId.blockedFirstSave;
}
