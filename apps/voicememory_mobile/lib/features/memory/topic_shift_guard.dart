import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import '../archive_packs/archive_pack_scope_policy.dart';
import '../archive_packs/entry_pack_scope.dart';
import '../pressure_retention/pressure_check_in_record.dart';
import 'archive_retrieval_policy.dart';
import 'clean_slate_prompt_state.dart';
import 'clean_slate_prompt_store.dart';
import 'current_relevance_gate.dart';
import 'entry_memory_mode.dart';
import 'entry_thread_scope.dart';
import 'memory_control_model.dart';
import 'memory_governance_decision.dart';
import 'memory_reliability_check.dart';
import 'memory_scope.dart';
import 'memory_scope_policy.dart';
import 'topic_shift_decision.dart';

/// Detects when recent archive context may bleed into a new entry direction.
abstract class TopicShiftGuard {
  TopicShiftGuard._();

  static const _noPrompt = TopicShiftDecision(
    shouldPrompt: false,
    decisionId: TopicShiftDecisionId.noShift,
    reasonId: TopicShiftReasonId.lowRelevance,
    suggestedAction: TopicShiftSuggestedAction.noAction,
  );

  static TopicShiftDecision evaluate({
    required int entryCount,
    required List<PressureCheckInRecord> records,
    MemoryCardType? cardType,
    DateTime? now,
    String source = 'record',
    bool trackAnalytics = true,
  }) {
    final decision = _evaluate(
      entryCount: entryCount,
      records: records,
      cardType: cardType ?? MemoryCardType.threadReturn,
      now: now,
    );

    if (trackAnalytics) {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.topicShiftChecked,
        entryCount: entryCount,
        memoryScope: MemoryScopePolicy.scope.id,
        source: source,
        decisionId: decision.decisionId,
        reasonId: decision.reasonId,
        suggestedAction: decision.suggestedAction,
      );
    }

    return decision;
  }

  static bool shouldSuppressMemoryClaims({
    required int entryCount,
    required List<PressureCheckInRecord> records,
    required MemoryCardType cardType,
    DateTime? now,
  }) {
    final decision = _evaluate(
      entryCount: entryCount,
      records: records,
      cardType: cardType,
      now: now,
    );
    return blocksMemoryClaims(decision);
  }

  static bool blocksMemoryClaims(TopicShiftDecision decision) {
    if (MemoryScopePolicy.scope == MemoryScope.off) return true;

    final choice = CleanSlatePromptStore.userChoice;
    if (choice == CleanSlateUserChoice.useArchiveContext) return false;
    if (choice == CleanSlateUserChoice.keepSeparate) return true;
    if (choice == CleanSlateUserChoice.startNewThread) return false;
    if (CleanSlatePromptStore.dismissedForSession) return false;
    if (!decision.shouldPrompt) return false;

    return decision.decisionId == TopicShiftDecisionId.adjacentButUnconfirmed ||
        decision.decisionId == TopicShiftDecisionId.differentThread ||
        decision.decisionId == TopicShiftDecisionId.differentPack ||
        decision.decisionId == TopicShiftDecisionId.recentContextConflict ||
        decision.decisionId == TopicShiftDecisionId.newDirectionPossible;
  }

  static TopicShiftDecision _evaluate({
    required int entryCount,
    required List<PressureCheckInRecord> records,
    required MemoryCardType cardType,
    DateTime? now,
  }) {
    CleanSlatePromptStore.noteSessionStart();

    if (MemoryScopePolicy.scope == MemoryScope.off) {
      return const TopicShiftDecision(
        shouldPrompt: false,
        decisionId: TopicShiftDecisionId.memoryOff,
        reasonId: TopicShiftReasonId.memoryOff,
        suggestedAction: TopicShiftSuggestedAction.noAction,
      );
    }

    if (entryCount == 0 || entryCount <= 1) {
      return _noPrompt;
    }

    if (CleanSlatePromptStore.isWithinFirstMinute(now: now)) {
      return _noPrompt;
    }

    if (CleanSlatePromptStore.dismissedForSession ||
        CleanSlatePromptStore.userChoice != null) {
      return const TopicShiftDecision(
        shouldPrompt: false,
        decisionId: TopicShiftDecisionId.noShift,
        reasonId: TopicShiftReasonId.explicitUserChoice,
        suggestedAction: TopicShiftSuggestedAction.noAction,
      );
    }

    if (EntryMemoryModeSession.selectedMode == EntryMemoryMode.treatAsNew) {
      return const TopicShiftDecision(
        shouldPrompt: false,
        decisionId: TopicShiftDecisionId.noShift,
        reasonId: TopicShiftReasonId.freshMode,
        suggestedAction: TopicShiftSuggestedAction.noAction,
      );
    }

    if (EntryMemoryModeSession.selectedMode == EntryMemoryMode.keepSeparate) {
      return const TopicShiftDecision(
        shouldPrompt: false,
        decisionId: TopicShiftDecisionId.noShift,
        reasonId: TopicShiftReasonId.keepSeparate,
        suggestedAction: TopicShiftSuggestedAction.noAction,
      );
    }

    final recent = _recentContextRecords(records, now: now);
    if (recent.isEmpty) {
      return _noPrompt;
    }

    final recentThread = CrossThreadDetector.primaryThreadId(recent);
    final recentPack = ArchivePackScopePolicy.primaryPackId(recent);

    if (EntryThreadScopeSession.selectedScope ==
            EntryThreadScope.existingThread &&
        EntryThreadScopeSession.selectedThreadId != null &&
        recentThread != null &&
        EntryThreadScopeSession.selectedThreadId != recentThread) {
      return const TopicShiftDecision(
        shouldPrompt: true,
        decisionId: TopicShiftDecisionId.differentThread,
        reasonId: TopicShiftReasonId.differentThread,
        suggestedAction: TopicShiftSuggestedAction.keepSeparate,
      );
    }

    if (EntryPackScopeSession.selectedScope == EntryPackScope.existingPack &&
        EntryPackScopeSession.selectedPackId != null &&
        recentPack != null &&
        EntryPackScopeSession.selectedPackId != recentPack) {
      return const TopicShiftDecision(
        shouldPrompt: true,
        decisionId: TopicShiftDecisionId.differentPack,
        reasonId: TopicShiftReasonId.differentPack,
        suggestedAction: TopicShiftSuggestedAction.keepSeparate,
      );
    }

    if (EntryThreadScopeSession.scopeExplicitlyChosen ||
        EntryPackScopeSession.scopeExplicitlyChosen) {
      return const TopicShiftDecision(
        shouldPrompt: false,
        decisionId: TopicShiftDecisionId.noShift,
        reasonId: TopicShiftReasonId.explicitUserChoice,
        suggestedAction: TopicShiftSuggestedAction.noAction,
      );
    }

    final reliability = MemoryReliabilityCheck.classify(
      cardType: cardType,
      records: records,
      now: now,
    );
    final relevanceBand = CurrentRelevanceGate.band(
      cardType: cardType,
      records: records,
      reliability: reliability,
      now: now,
    );

    if (relevanceBand == RelevanceBand.none ||
        relevanceBand == RelevanceBand.low ||
        reliability.state == MemoryReliabilityState.blocked ||
        reliability.state == MemoryReliabilityState.lowEvidence) {
      return const TopicShiftDecision(
        shouldPrompt: false,
        decisionId: TopicShiftDecisionId.noShift,
        reasonId: TopicShiftReasonId.lowRelevance,
        suggestedAction: TopicShiftSuggestedAction.noAction,
      );
    }

    final retrieval = ArchiveRetrievalPolicy.retrieve(
      records,
      now: now,
      cardType: cardType.id,
    );
    final temptingRetrieval = retrieval.supportsConnectionClaims;

    final sameThreadBound =
        recentThread != null &&
        recent.every(
          (r) =>
              r.archiveThreadId == null ||
              r.archiveThreadId!.isEmpty ||
              r.archiveThreadId == recentThread,
        );
    final samePackBound =
        recentPack != null &&
        recent.every(
          (r) =>
              r.archivePackId == null ||
              r.archivePackId!.isEmpty ||
              r.archivePackId == recentPack,
        );

    if (sameThreadBound) {
      return const TopicShiftDecision(
        shouldPrompt: false,
        decisionId: TopicShiftDecisionId.noShift,
        reasonId: TopicShiftReasonId.sameThread,
        suggestedAction: TopicShiftSuggestedAction.useArchiveContext,
      );
    }

    if (samePackBound) {
      return const TopicShiftDecision(
        shouldPrompt: false,
        decisionId: TopicShiftDecisionId.noShift,
        reasonId: TopicShiftReasonId.samePack,
        suggestedAction: TopicShiftSuggestedAction.useArchiveContext,
      );
    }

    if (temptingRetrieval &&
        (reliability.state == MemoryReliabilityState.crossThread ||
            reliability.state == MemoryReliabilityState.crossPack ||
            reliability.state == MemoryReliabilityState.mixedEvidence)) {
      return const TopicShiftDecision(
        shouldPrompt: true,
        decisionId: TopicShiftDecisionId.adjacentButUnconfirmed,
        reasonId: TopicShiftReasonId.samePack,
        suggestedAction: TopicShiftSuggestedAction.keepSeparate,
      );
    }

    if (temptingRetrieval && (recentThread != null || recentPack != null)) {
      return const TopicShiftDecision(
        shouldPrompt: true,
        decisionId: TopicShiftDecisionId.newDirectionPossible,
        reasonId: TopicShiftReasonId.sameThread,
        suggestedAction: TopicShiftSuggestedAction.startNewThread,
      );
    }

    if (temptingRetrieval) {
      return const TopicShiftDecision(
        shouldPrompt: true,
        decisionId: TopicShiftDecisionId.recentContextConflict,
        reasonId: TopicShiftReasonId.samePack,
        suggestedAction: TopicShiftSuggestedAction.keepSeparate,
      );
    }

    return _noPrompt;
  }

  static List<PressureCheckInRecord> _recentContextRecords(
    List<PressureCheckInRecord> records, {
    DateTime? now,
  }) {
    final anchor = now ?? DateTime.now();
    return records
        .where((r) => !r.treatAsNew && !r.keepSeparate)
        .where((r) => r.entryAboutness == 'about_me')
        .where((r) => r.memorySurfacing == 'normal')
        .where(
          (r) => anchor.difference(r.createdAt) <= const Duration(days: 14),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static void resetPersistedState() {
    CleanSlatePromptStore.resetSessionState();
    EntryMemoryModeSession.resetSessionState();
    EntryThreadScopeSession.resetSessionState();
    EntryPackScopeSession.resetSessionState();
  }

  @visibleForTesting
  static void resetForTest() => resetPersistedState();
}
