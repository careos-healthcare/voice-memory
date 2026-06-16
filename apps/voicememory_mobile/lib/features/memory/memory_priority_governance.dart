import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import '../archive_packs/archive_pack_scope_policy.dart';
import '../archive_packs/cross_pack_confirmation.dart';
import '../pressure_retention/pressure_check_in_record.dart';
import 'memory_authority_framing_engine.dart';
import 'memory_authority_frame.dart';
import 'memory_connection_rules.dart';
import 'memory_control_model.dart';
import 'memory_control_store.dart';
import 'memory_governance_decision.dart';
import 'memory_priority_decision.dart';
import 'memory_priority_score.dart';
import 'memory_reliability_check.dart';
import 'memory_scope.dart';
import 'memory_scope_policy.dart';
import 'not_important_feedback.dart';
import 'wrong_thread_feedback.dart';

/// Memory priority governance — orders evidence after relevance governance.
///
/// Pipeline: scope → pack/thread → relevance → priority → authority → receipt.
/// Priority never widens governance; it only narrows, suppresses, or orders.
abstract class MemoryPriorityGovernance {
  MemoryPriorityGovernance._();

  static MemoryPriorityDecision evaluate({
    required MemoryCardType cardType,
    required List<PressureCheckInRecord> records,
    required MemoryGovernanceDecision governance,
    MemoryAuthorityFraming? framing,
    DateTime? now,
    bool trackAnalytics = true,
    String source = 'memory_card',
    int entryCount = 1,
  }) {
    if (trackAnalytics) {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.memoryPriorityChecked,
        cardType: cardType.id,
        memoryScope: MemoryScopePolicy.scope.id,
        source: source,
        entryCount: entryCount,
      );
    }

    final anchor = now ?? DateTime.now();
    final frame =
        framing ??
        governance.reliability?.framing ??
        const MemoryAuthorityFramingEngine().frame(
          records,
          now: anchor,
          cardType: cardType,
        );
    final candidates = frame.candidates;

    // Suppression ladder — governance must approve before priority can allow.
    if (MemoryScopePolicy.scope == MemoryScope.off ||
        governance.decisionId == MemoryGovernanceDecisionId.blockedMemoryOff) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: _suppressed(
          MemoryPriorityDecisionId.suppressedFresh,
          MemoryPriorityReasonId.freshEntry,
          MemoryPriorityExplanationId.notImportantDemoted,
        ),
        event: ActivationFunnelAnalytics.memoryPrioritySuppressed,
      );
    }

    if (governance.decisionId == MemoryGovernanceDecisionId.blockedFreshEntry ||
        records.any((r) => r.treatAsNew)) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: _suppressed(
          MemoryPriorityDecisionId.suppressedFresh,
          MemoryPriorityReasonId.freshEntry,
          MemoryPriorityExplanationId.notImportantDemoted,
        ),
        event: ActivationFunnelAnalytics.memoryPrioritySuppressed,
      );
    }

    if (governance.decisionId ==
            MemoryGovernanceDecisionId.blockedKeepSeparate ||
        records.any((r) => r.keepSeparate)) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: _suppressed(
          MemoryPriorityDecisionId.suppressedKeepSeparate,
          MemoryPriorityReasonId.keepSeparate,
          MemoryPriorityExplanationId.notImportantDemoted,
        ),
        event: ActivationFunnelAnalytics.memoryPrioritySuppressed,
      );
    }

    if (MemoryControlStore.isSuppressed(cardType)) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: _suppressed(
          MemoryPriorityDecisionId.suppressedNotRelated,
          MemoryPriorityReasonId.notRelated,
          MemoryPriorityExplanationId.notImportantDemoted,
        ),
        event: ActivationFunnelAnalytics.memoryPrioritySuppressed,
      );
    }

    if (WrongThreadFeedback.isSessionSuppressed(cardType) ||
        governance.decisionId ==
            MemoryGovernanceDecisionId.blockedWrongThread) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: _suppressed(
          MemoryPriorityDecisionId.suppressedWrongThread,
          MemoryPriorityReasonId.wrongThread,
          MemoryPriorityExplanationId.notImportantDemoted,
        ),
        event: ActivationFunnelAnalytics.memoryPrioritySuppressed,
      );
    }

    if (CrossPackConfirmation.isSessionSuppressed(cardType.id) ||
        governance.decisionId == MemoryGovernanceDecisionId.blockedWrongPack) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: _suppressed(
          MemoryPriorityDecisionId.suppressedWrongPack,
          MemoryPriorityReasonId.wrongPack,
          MemoryPriorityExplanationId.notImportantDemoted,
        ),
        event: ActivationFunnelAnalytics.memoryPrioritySuppressed,
      );
    }

    if (NotImportantFeedback.isDemoted(cardType)) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: _suppressed(
          MemoryPriorityDecisionId.suppressedNotImportant,
          MemoryPriorityReasonId.notImportant,
          MemoryPriorityExplanationId.notImportantDemoted,
        ),
        event: ActivationFunnelAnalytics.memoryPrioritySuppressed,
      );
    }

    final evidencePool = candidates.isNotEmpty ? candidates : records;
    if (MemoryPriorityScore.isOldOneOff(evidencePool, anchor: anchor) &&
        !MemoryConnectionRules.isConfirmed(cardType.id) &&
        !evidencePool.any((r) => r.connectionApproved)) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: _background(
          MemoryPriorityDecisionId.backgroundOldOneOff,
          MemoryPriorityReasonId.oldOneOff,
          MemoryPriorityExplanationId.oldOneOffBackground,
        ),
        event: ActivationFunnelAnalytics.memoryPriorityBackgroundOnly,
      );
    }

    if (governance.requiresUserConfirmation) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: MemoryPriorityDecision(
          priorityBand: MemoryPriorityBand.normal,
          decisionId: MemoryPriorityDecisionId.normalRecentRelated,
          reasonIds: const [MemoryPriorityReasonId.recentEvidence],
          shouldSuppress: false,
          backgroundOnly: false,
          canSupportClaim: false,
          canOutrankCurrentContext: false,
          safeExplanationId: MemoryPriorityExplanationId.recentRelated,
        ),
        event: ActivationFunnelAnalytics.memoryPriorityChecked,
      );
    }

    if (!governance.allowsMemoryClaim &&
        !governance.showBackgroundOnly &&
        !governance.requiresUserConfirmation) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: _suppressed(
          MemoryPriorityDecisionId.suppressedNotRelated,
          MemoryPriorityReasonId.notRelated,
          MemoryPriorityExplanationId.notImportantDemoted,
        ),
        event: ActivationFunnelAnalytics.memoryPrioritySuppressed,
      );
    }

    final reliability = governance.reliability;
    if (reliability?.state == MemoryReliabilityState.mixedEvidence) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: _background(
          MemoryPriorityDecisionId.backgroundMixed,
          MemoryPriorityReasonId.mixedEvidence,
          MemoryPriorityExplanationId.mixedCautious,
        ),
        event: ActivationFunnelAnalytics.memoryPriorityBackgroundOnly,
      );
    }

    if (reliability?.state == MemoryReliabilityState.staleEvidence ||
        frame.frame.authorityState == MemoryAuthorityState.stale ||
        frame.frame.authorityState == MemoryAuthorityState.superseded) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: _background(
          MemoryPriorityDecisionId.backgroundStale,
          MemoryPriorityReasonId.staleEvidence,
          MemoryPriorityExplanationId.oldOneOffBackground,
        ),
        event: ActivationFunnelAnalytics.memoryPriorityBackgroundOnly,
      );
    }

    if (candidates.isEmpty) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: _background(
          MemoryPriorityDecisionId.backgroundOldOneOff,
          MemoryPriorityReasonId.oldOneOff,
          MemoryPriorityExplanationId.oldOneOffBackground,
        ),
        event: ActivationFunnelAnalytics.memoryPriorityBackgroundOnly,
      );
    }

    if (MemoryPriorityScore.isOldOneOff(candidates, anchor: anchor) &&
        !MemoryConnectionRules.isConfirmed(cardType.id) &&
        !candidates.any((r) => r.connectionApproved)) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: _background(
          MemoryPriorityDecisionId.backgroundOldOneOff,
          MemoryPriorityReasonId.oldOneOff,
          MemoryPriorityExplanationId.oldOneOffBackground,
        ),
        event: ActivationFunnelAnalytics.memoryPriorityBackgroundOnly,
      );
    }

    final groupCount = MemoryPriorityScore.distinctEvidenceGroups(candidates);
    final explicitThread = WrongThreadFeedback.explicitThreadFor(cardType);
    final sameThread =
        explicitThread != null &&
        candidates.every((r) => r.archiveThreadId == explicitThread);
    final anchorPack = ArchivePackScopePolicy.primaryPackId(candidates);
    final samePack =
        anchorPack != null &&
        candidates.every((r) => r.archivePackId == anchorPack) &&
        (ArchivePackScopePolicy.allowsCrossPackByPolicy(candidates) ||
            !ArchivePackScopePolicy.isCrossPack(candidates));

    final userConfirmed =
        MemoryConnectionRules.isConfirmed(cardType.id) ||
        candidates.any((r) => r.connectionApproved) ||
        frame.frame.authorityState == MemoryAuthorityState.confirmed;

    if (userConfirmed && governance.allowsMemoryClaim) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: MemoryPriorityDecision(
          priorityBand: MemoryPriorityBand.essential,
          decisionId: MemoryPriorityDecisionId.essentialUserConfirmed,
          reasonIds: const [MemoryPriorityReasonId.userConfirmed],
          shouldSuppress: false,
          backgroundOnly: false,
          canSupportClaim: true,
          canOutrankCurrentContext: false,
          safeExplanationId: MemoryPriorityExplanationId.userConfirmed,
        ),
        event: ActivationFunnelAnalytics.memoryPriorityUsed,
      );
    }

    if (sameThread && groupCount >= MemoryPriorityScore.repeatedGroupCount) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: MemoryPriorityDecision(
          priorityBand: MemoryPriorityBand.important,
          decisionId: MemoryPriorityDecisionId.importantSameThread,
          reasonIds: const [
            MemoryPriorityReasonId.sameThread,
            MemoryPriorityReasonId.repeatedEvidence,
          ],
          shouldSuppress: false,
          backgroundOnly: false,
          canSupportClaim: governance.allowsMemoryClaim,
          canOutrankCurrentContext: false,
          safeExplanationId: MemoryPriorityExplanationId.sameThread,
        ),
        event: ActivationFunnelAnalytics.memoryPriorityUsed,
      );
    }

    if (samePack && groupCount >= MemoryPriorityScore.repeatedGroupCount) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: MemoryPriorityDecision(
          priorityBand: MemoryPriorityBand.important,
          decisionId: MemoryPriorityDecisionId.importantSamePack,
          reasonIds: const [
            MemoryPriorityReasonId.samePack,
            MemoryPriorityReasonId.repeatedEvidence,
          ],
          shouldSuppress: false,
          backgroundOnly: false,
          canSupportClaim: governance.allowsMemoryClaim,
          canOutrankCurrentContext: false,
          safeExplanationId: MemoryPriorityExplanationId.samePack,
        ),
        event: ActivationFunnelAnalytics.memoryPriorityUsed,
      );
    }

    if (groupCount >= MemoryPriorityScore.repeatedGroupCount) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: MemoryPriorityDecision(
          priorityBand: MemoryPriorityBand.important,
          decisionId: MemoryPriorityDecisionId.importantRepeated,
          reasonIds: const [MemoryPriorityReasonId.repeatedEvidence],
          shouldSuppress: false,
          backgroundOnly: false,
          canSupportClaim: governance.allowsMemoryClaim,
          canOutrankCurrentContext: false,
          safeExplanationId: MemoryPriorityExplanationId.repeated,
        ),
        event: ActivationFunnelAnalytics.memoryPriorityUsed,
      );
    }

    final ranked = MemoryPriorityScore.rankedCandidates(
      candidates,
      cardType: cardType,
      anchor: anchor,
    );
    final top = ranked.first;
    final hasPinnedTieBreak =
        top.isPinned && groupCount >= 2 && governance.allowsMemoryClaim;
    final hasExactTieBreak =
        top.keepExactDetails && groupCount >= 2 && governance.allowsMemoryClaim;

    if (hasPinnedTieBreak) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: MemoryPriorityDecision(
          priorityBand: MemoryPriorityBand.important,
          decisionId: MemoryPriorityDecisionId.importantPinned,
          reasonIds: const [
            MemoryPriorityReasonId.pinnedEvidence,
            MemoryPriorityReasonId.recentEvidence,
          ],
          shouldSuppress: false,
          backgroundOnly: false,
          canSupportClaim: true,
          canOutrankCurrentContext: false,
          safeExplanationId: MemoryPriorityExplanationId.pinned,
        ),
        event: ActivationFunnelAnalytics.memoryPriorityUsed,
      );
    }

    if (hasExactTieBreak) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: MemoryPriorityDecision(
          priorityBand: MemoryPriorityBand.important,
          decisionId: MemoryPriorityDecisionId.importantExact,
          reasonIds: const [
            MemoryPriorityReasonId.exactEvidence,
            MemoryPriorityReasonId.recentEvidence,
          ],
          shouldSuppress: false,
          backgroundOnly: false,
          canSupportClaim: true,
          canOutrankCurrentContext: false,
          safeExplanationId: MemoryPriorityExplanationId.exact,
        ),
        event: ActivationFunnelAnalytics.memoryPriorityUsed,
      );
    }

    final newest = candidates.reduce(
      (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
    );
    if (anchor.difference(newest.createdAt).inDays <=
        MemoryPriorityScore.recentDays) {
      return _finish(
        cardType: cardType,
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        decision: MemoryPriorityDecision(
          priorityBand: MemoryPriorityBand.normal,
          decisionId: MemoryPriorityDecisionId.normalRecentRelated,
          reasonIds: const [MemoryPriorityReasonId.recentEvidence],
          shouldSuppress: false,
          backgroundOnly: false,
          canSupportClaim: governance.allowsMemoryClaim,
          canOutrankCurrentContext: false,
          safeExplanationId: MemoryPriorityExplanationId.recentRelated,
        ),
        event: ActivationFunnelAnalytics.memoryPriorityUsed,
      );
    }

    return _finish(
      cardType: cardType,
      trackAnalytics: trackAnalytics,
      source: source,
      entryCount: entryCount,
      decision: _background(
        MemoryPriorityDecisionId.backgroundOldOneOff,
        MemoryPriorityReasonId.oldOneOff,
        MemoryPriorityExplanationId.oldOneOffBackground,
      ),
      event: ActivationFunnelAnalytics.memoryPriorityBackgroundOnly,
    );
  }

  /// Filters candidates to those that should carry a claim after priority.
  static List<PressureCheckInRecord> filterCandidates(
    List<PressureCheckInRecord> candidates, {
    required MemoryCardType cardType,
    required MemoryPriorityDecision priority,
    DateTime? anchor,
    bool confirmationPending = false,
  }) {
    if (confirmationPending) return candidates;
    if (priority.shouldSuppress || !priority.canSupportClaim) {
      return const [];
    }
    if (candidates.isEmpty) return const [];
    final clock = anchor ?? DateTime.now();
    final ranked = MemoryPriorityScore.rankedCandidates(
      candidates,
      cardType: cardType,
      anchor: clock,
    );
    if (priority.priorityBand == MemoryPriorityBand.essential ||
        priority.priorityBand == MemoryPriorityBand.important) {
      return ranked;
    }
    if (priority.backgroundOnly) {
      return ranked.take(1).toList();
    }
    return ranked;
  }

  static bool permitsEngineBuild(
    MemoryPriorityDecision priority, {
    bool confirmationPending = false,
  }) =>
      !priority.shouldSuppress &&
      (priority.canSupportClaim ||
          priority.backgroundOnly ||
          confirmationPending);

  static MemoryPriorityDecision _suppressed(
    String decisionId,
    String reasonId,
    String explanationId,
  ) => MemoryPriorityDecision(
    priorityBand: MemoryPriorityBand.suppressed,
    decisionId: decisionId,
    reasonIds: [reasonId],
    shouldSuppress: true,
    backgroundOnly: false,
    canSupportClaim: false,
    canOutrankCurrentContext: false,
    safeExplanationId: explanationId,
  );

  static MemoryPriorityDecision _background(
    String decisionId,
    String reasonId,
    String explanationId,
  ) => MemoryPriorityDecision(
    priorityBand: MemoryPriorityBand.background,
    decisionId: decisionId,
    reasonIds: [reasonId],
    shouldSuppress: false,
    backgroundOnly: true,
    canSupportClaim: false,
    canOutrankCurrentContext: false,
    safeExplanationId: explanationId,
  );

  static MemoryPriorityDecision _finish({
    required MemoryCardType cardType,
    required bool trackAnalytics,
    required String source,
    required int entryCount,
    required MemoryPriorityDecision decision,
    required String event,
  }) {
    MemoryPriorityDecisionLog.record(cardType, decision);
    if (trackAnalytics) {
      ActivationFunnelAnalytics.track(
        event,
        cardType: cardType.id,
        decisionId: decision.decisionId,
        reasonId: decision.reasonIds.first,
        priorityBand: decision.priorityBand.id,
        memoryScope: MemoryScopePolicy.scope.id,
        source: source,
        entryCount: entryCount,
      );
    }
    return decision;
  }

  @visibleForTesting
  static void resetForTest() {
    MemoryPriorityDecisionLog.resetForTest();
    NotImportantFeedback.resetForTest();
  }
}
