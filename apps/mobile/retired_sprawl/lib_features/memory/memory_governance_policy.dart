import 'package:archiveme_mobile/features/archive_packs/archive_pack_scope_policy.dart';
import 'package:archiveme_mobile/features/archive_packs/cross_pack_confirmation.dart';
import 'package:archiveme_mobile/features/memory/cross_thread_confirmation.dart';
import 'package:archiveme_mobile/features/memory/current_intent_signal.dart';
import 'package:archiveme_mobile/features/memory/current_relevance_gate.dart';
import 'package:archiveme_mobile/features/memory/entry_aboutness.dart';
import 'package:archiveme_mobile/features/memory/memory_authority_frame.dart';
import 'package:archiveme_mobile/features/memory/memory_authority_framing_engine.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_governance_decision.dart';
import 'package:archiveme_mobile/features/memory/memory_reliability_check.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/memory/memory_surfacing_mode.dart';
import 'package:archiveme_mobile/features/memory/not_about_me_policy.dart';
import 'package:archiveme_mobile/features/memory/sensitive_surfacing_policy.dart';
import 'package:archiveme_mobile/features/memory/topic_shift_guard.dart';
import 'package:archiveme_mobile/features/memory/wrong_thread_feedback.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

/// Memory governance — decides whether archive context may matter right now.
///
/// Retrieval asks: "Can we find an old memory?"
/// Governance asks: "Should this memory matter right now?"
///
/// Order: scope → aboutness → sensitive surfacing → topic shift → pack/thread
/// boundary → relevance → priority → authority → receipt.
/// Never overrides Memory Scope Controls; never re-enables memory when off.
abstract class MemoryGovernancePolicy {
  MemoryGovernancePolicy._();

  static MemoryGovernanceDecision evaluate({
    required MemoryCardType cardType,
    required List<PressureCheckInRecord> records,
    required int entryCount,
    bool searchingArchive = false,
    bool trackAnalytics = true,
    DateTime? now,
    String source = 'memory_card',
  }) {
    var scopedRecords = records;
    final intent = CurrentIntentSignal.classify(
      cardType: cardType,
      records: records,
      entryCount: entryCount,
      searchingArchive: searchingArchive,
    );

    if (trackAnalytics) {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.memoryGovernanceChecked,
        cardType: cardType.id,
        currentIntent: intent.id,
        memoryScope: MemoryScopePolicy.scope.id,
        source: source,
        entryCount: entryCount,
      );
    }

    // 1. Global memory off.
    if (MemoryScopePolicy.scope == MemoryScope.off) {
      return _finish(
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        cardType: cardType,
        intent: intent,
        decision: MemoryGovernanceDecision(
          allowed: false,
          decisionId: MemoryGovernanceDecisionId.blockedMemoryOff,
          reasonId: MemoryAuthorityReason.memoryOff,
          currentIntent: intent,
          relevanceBand: RelevanceBand.none,
          requiresUserConfirmation: false,
        ),
        event: ActivationFunnelAnalytics.memoryGovernanceBlocked,
      );
    }

    // 2. First save.
    if (intent == CurrentIntent.firstSave) {
      return _finish(
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        cardType: cardType,
        intent: intent,
        decision: MemoryGovernanceDecision(
          allowed: false,
          decisionId: MemoryGovernanceDecisionId.blockedFirstSave,
          reasonId: 'first_save',
          currentIntent: intent,
          relevanceBand: RelevanceBand.none,
          requiresUserConfirmation: false,
        ),
        event: ActivationFunnelAnalytics.memoryGovernanceBlocked,
      );
    }

    // 3. Fresh / treat-as-new.
    if (intent == CurrentIntent.freshEntry) {
      return _finish(
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        cardType: cardType,
        intent: intent,
        decision: MemoryGovernanceDecision(
          allowed: false,
          decisionId: MemoryGovernanceDecisionId.blockedFreshEntry,
          reasonId: MemoryAuthorityReason.freshEntry,
          currentIntent: intent,
          relevanceBand: RelevanceBand.none,
          requiresUserConfirmation: false,
        ),
        event: ActivationFunnelAnalytics.memoryGovernanceBlocked,
      );
    }

    // 4. Keep separate.
    if (intent == CurrentIntent.keepSeparate ||
        records.any((r) => r.keepSeparate)) {
      return _finish(
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        cardType: cardType,
        intent: intent,
        decision: MemoryGovernanceDecision(
          allowed: false,
          decisionId: MemoryGovernanceDecisionId.blockedKeepSeparate,
          reasonId: 'keep_separate',
          currentIntent: intent,
          relevanceBand: RelevanceBand.none,
          requiresUserConfirmation: false,
        ),
        event: ActivationFunnelAnalytics.memoryGovernanceBlocked,
      );
    }

    // 4a. Non-personal entries — saved, not personal evidence.
    if (source == 'record' &&
        NotAboutMePolicy.blocksPersonalMemoryClaims(
          EntryAboutnessSession.selected,
        )) {
      if (trackAnalytics) {
        NotAboutMePolicy.trackBlocked(source: source, entryCount: entryCount);
      }
      return _finish(
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        cardType: cardType,
        intent: intent,
        decision: MemoryGovernanceDecision(
          allowed: false,
          decisionId: MemoryGovernanceDecisionId.blockedFreshEntry,
          reasonId: MemoryAuthorityReason.freshEntry,
          currentIntent: intent,
          relevanceBand: RelevanceBand.none,
          requiresUserConfirmation: false,
        ),
        event: ActivationFunnelAnalytics.memoryGovernanceBlocked,
      );
    }

    // 4a2. Do-not-surface on compose — keep new entry out of proactive claims.
    if (source == 'record' &&
        MemorySurfacingSession.selected.blocksProactiveResurfacing) {
      if (trackAnalytics) {
        SensitiveSurfacingPolicy.trackBlocked(
          surfaceType: MemorySurfaceType.recordContext,
          mode: MemorySurfacingSession.selected,
          source: source,
          entryCount: entryCount,
        );
      }
      return _finish(
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        cardType: cardType,
        intent: intent,
        decision: MemoryGovernanceDecision(
          allowed: false,
          decisionId: MemoryGovernanceDecisionId.blockedFreshEntry,
          reasonId: MemoryAuthorityReason.freshEntry,
          currentIntent: intent,
          relevanceBand: RelevanceBand.none,
          requiresUserConfirmation: false,
        ),
        event: ActivationFunnelAnalytics.memoryGovernanceBlocked,
      );
    }

    var claimRecords = records;
    if (NotAboutMePolicy.isPersonalMemoryCard(cardType)) {
      claimRecords = NotAboutMePolicy.personalEvidenceOnly(records);
      if (claimRecords.isEmpty && records.isNotEmpty) {
        if (trackAnalytics) {
          NotAboutMePolicy.trackBlocked(source: source, entryCount: entryCount);
        }
        return _finish(
          trackAnalytics: trackAnalytics,
          source: source,
          entryCount: entryCount,
          cardType: cardType,
          intent: intent,
          decision: MemoryGovernanceDecision(
            allowed: false,
            decisionId: MemoryGovernanceDecisionId.blockedFreshEntry,
            reasonId: MemoryAuthorityReason.freshEntry,
            currentIntent: intent,
            relevanceBand: RelevanceBand.none,
            requiresUserConfirmation: false,
          ),
          event: ActivationFunnelAnalytics.memoryGovernanceBlocked,
        );
      }
      scopedRecords = claimRecords;

      // 4c. Sensitive surfacing — filter user-protected entries from claims.
      final beforeSurfacing = scopedRecords.length;
      scopedRecords = SensitiveSurfacingPolicy.proactiveClaimEligible(
        scopedRecords,
      );
      if (scopedRecords.isEmpty && beforeSurfacing > 0) {
        final blockedMode =
            records.any(SensitiveSurfacingPolicy.isDoNotSurfaceRecord)
            ? MemorySurfacingMode.doNotSurface
            : MemorySurfacingMode.sensitive;
        if (trackAnalytics) {
          SensitiveSurfacingPolicy.trackBlocked(
            surfaceType: MemorySurfaceType.fromCardType(cardType),
            mode: blockedMode,
            source: source,
            entryCount: entryCount,
          );
        }
        return _finish(
          trackAnalytics: trackAnalytics,
          source: source,
          entryCount: entryCount,
          cardType: cardType,
          intent: intent,
          decision: MemoryGovernanceDecision(
            allowed: false,
            decisionId: MemoryGovernanceDecisionId.blockedFreshEntry,
            reasonId: MemoryAuthorityReason.freshEntry,
            currentIntent: intent,
            relevanceBand: RelevanceBand.none,
            requiresUserConfirmation: false,
          ),
          event: ActivationFunnelAnalytics.memoryGovernanceBlocked,
        );
      }
    }

    // 4b. Topic shift — only while composing on the record screen.
    if (source == 'record' &&
        TopicShiftGuard.shouldSuppressMemoryClaims(
          entryCount: entryCount,
          records: scopedRecords,
          cardType: cardType,
          now: now,
        )) {
      final topicShift = TopicShiftGuard.evaluate(
        entryCount: entryCount,
        records: scopedRecords,
        cardType: cardType,
        now: now,
        trackAnalytics: false,
        source: source,
      );
      return _finish(
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        cardType: cardType,
        intent: intent,
        decision: MemoryGovernanceDecision(
          allowed: false,
          decisionId: MemoryGovernanceDecisionId.blockedLowRelevance,
          reasonId: topicShift.reasonId,
          currentIntent: intent,
          relevanceBand: RelevanceBand.low,
          requiresUserConfirmation: topicShift.shouldPrompt,
        ),
        event: ActivationFunnelAnalytics.memoryGovernanceBlocked,
      );
    }

    // 5. Wrong-thread durable rules.
    if (WrongThreadFeedback.isSessionSuppressed(cardType)) {
      return _finish(
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        cardType: cardType,
        intent: intent,
        decision: MemoryGovernanceDecision(
          allowed: false,
          decisionId: MemoryGovernanceDecisionId.blockedWrongThread,
          reasonId: MemoryAuthorityReason.freshEntry,
          currentIntent: intent,
          relevanceBand: RelevanceBand.none,
          requiresUserConfirmation: false,
        ),
        event: ActivationFunnelAnalytics.memoryGovernanceBlocked,
      );
    }

    if (CrossPackConfirmation.isSessionSuppressed(cardType.id)) {
      return _finish(
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        cardType: cardType,
        intent: intent,
        decision: MemoryGovernanceDecision(
          allowed: false,
          decisionId: MemoryGovernanceDecisionId.blockedWrongPack,
          reasonId: 'keep_separate',
          currentIntent: intent,
          relevanceBand: RelevanceBand.none,
          requiresUserConfirmation: false,
        ),
        event: ActivationFunnelAnalytics.memoryGovernanceBlocked,
      );
    }

    final reliability = MemoryReliabilityCheck.classify(
      cardType: cardType,
      records: scopedRecords,
      now: now,
    );
    final relevanceBand = CurrentRelevanceGate.band(
      cardType: cardType,
      records: scopedRecords,
      reliability: reliability,
      now: now,
    );
    final framing =
        reliability.framing ??
        const MemoryAuthorityFramingEngine().frame(
          scopedRecords,
          now: now,
          cardType: cardType,
        );

    // Searching archive: results OK, connection claims gated elsewhere.
    if (intent == CurrentIntent.searchingArchive) {
      return _finish(
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        cardType: cardType,
        intent: intent,
        decision: MemoryGovernanceDecision(
          allowed: false,
          decisionId: MemoryGovernanceDecisionId.blockedLowRelevance,
          reasonId: 'searching_archive',
          currentIntent: intent,
          relevanceBand: relevanceBand,
          requiresUserConfirmation: false,
          reliability: reliability,
        ),
        event: ActivationFunnelAnalytics.memoryGovernanceBlocked,
      );
    }

    // Cross-thread confirmation before claim.
    if (reliability.requiresCrossThreadConfirmation &&
        !CrossThreadConfirmation.isApproved(cardType)) {
      return _finish(
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        cardType: cardType,
        intent: intent,
        decision: MemoryGovernanceDecision(
          allowed: false,
          decisionId: MemoryGovernanceDecisionId.confirmCrossThread,
          reasonId: MemoryAuthorityReason.repeatedSupported,
          currentIntent: intent,
          relevanceBand: relevanceBand,
          requiresUserConfirmation: true,
          reliability: reliability,
        ),
        event: ActivationFunnelAnalytics.memoryGovernanceConfirmationRequired,
      );
    }

    // Cross-pack confirmation before claim.
    if (reliability.requiresCrossPackConfirmation &&
        !CrossPackConfirmation.isApproved(cardType.id)) {
      return _finish(
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        cardType: cardType,
        intent: intent,
        decision: MemoryGovernanceDecision(
          allowed: false,
          decisionId: MemoryGovernanceDecisionId.confirmCrossPack,
          reasonId: MemoryAuthorityReason.repeatedSupported,
          currentIntent: intent,
          relevanceBand: relevanceBand,
          requiresUserConfirmation: true,
          reliability: reliability,
        ),
        event: ActivationFunnelAnalytics.memoryGovernanceConfirmationRequired,
      );
    }

    // Cross-thread approved by user.
    if (CrossThreadConfirmation.isApproved(cardType)) {
      return _finish(
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        cardType: cardType,
        intent: intent,
        decision: MemoryGovernanceDecision(
          allowed: true,
          decisionId: MemoryGovernanceDecisionId.allowedUserConfirmed,
          reasonId: MemoryAuthorityReason.userConfirmed,
          currentIntent: intent,
          relevanceBand: relevanceBand,
          requiresUserConfirmation: false,
          reliability: reliability,
        ),
        event: ActivationFunnelAnalytics.memoryGovernanceAllowed,
      );
    }

    // Cross-pack approved by user.
    if (CrossPackConfirmation.isApproved(cardType.id)) {
      return _finish(
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        cardType: cardType,
        intent: intent,
        decision: MemoryGovernanceDecision(
          allowed: true,
          decisionId: MemoryGovernanceDecisionId.allowedUserConfirmed,
          reasonId: MemoryAuthorityReason.userConfirmed,
          currentIntent: intent,
          relevanceBand: relevanceBand,
          requiresUserConfirmation: false,
          reliability: reliability,
        ),
        event: ActivationFunnelAnalytics.memoryGovernanceAllowed,
      );
    }

    // User-confirmed evidence passes unless blocked above.
    final userConfirmed =
        framing.frame.authorityState == MemoryAuthorityState.confirmed ||
        framing.candidates.any((r) => r.connectionApproved);
    if (userConfirmed) {
      return _finish(
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        cardType: cardType,
        intent: intent,
        decision: MemoryGovernanceDecision(
          allowed: true,
          decisionId: MemoryGovernanceDecisionId.allowedUserConfirmed,
          reasonId: MemoryAuthorityReason.userConfirmed,
          currentIntent: intent,
          relevanceBand: relevanceBand,
          requiresUserConfirmation: false,
          reliability: reliability,
        ),
        event: ActivationFunnelAnalytics.memoryGovernanceAllowed,
      );
    }

    // Low relevance blocks major claims.
    if (relevanceBand == RelevanceBand.none ||
        relevanceBand == RelevanceBand.low ||
        reliability.state == MemoryReliabilityState.blocked ||
        reliability.state == MemoryReliabilityState.lowEvidence) {
      return _finish(
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        cardType: cardType,
        intent: intent,
        decision: MemoryGovernanceDecision(
          allowed: false,
          decisionId: MemoryGovernanceDecisionId.blockedLowRelevance,
          reasonId:
              reliability.framing?.frame.reasonId ??
              MemoryAuthorityReason.freshEntry,
          currentIntent: intent,
          relevanceBand: relevanceBand,
          requiresUserConfirmation: false,
          reliability: reliability,
        ),
        event: ActivationFunnelAnalytics.memoryGovernanceBlocked,
      );
    }

    // Medium relevance → background only, not a major claim.
    if (relevanceBand == RelevanceBand.medium &&
        (reliability.state == MemoryReliabilityState.mixedEvidence ||
            reliability.state == MemoryReliabilityState.staleEvidence)) {
      return _finish(
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        cardType: cardType,
        intent: intent,
        decision: MemoryGovernanceDecision(
          allowed: true,
          decisionId: MemoryGovernanceDecisionId.backgroundOnly,
          reasonId:
              reliability.framing?.frame.reasonId ??
              MemoryAuthorityReason.mixedEvidence,
          currentIntent: intent,
          relevanceBand: relevanceBand,
          requiresUserConfirmation: false,
          reliability: reliability,
        ),
        event: ActivationFunnelAnalytics.memoryBackgroundOnly,
      );
    }

    // Same explicit thread when thread-bound.
    if (intent == CurrentIntent.threadBound) {
      final explicitThread = WrongThreadFeedback.explicitThreadFor(cardType);
      final candidates = framing.candidates;
      if (explicitThread != null &&
          candidates.isNotEmpty &&
          candidates.every((r) => r.archiveThreadId == explicitThread) &&
          framing.allowsConnectionClaims &&
          CurrentRelevanceGate.candidateMattersNow(
            cardType: cardType,
            records: scopedRecords,
            relevanceBand: relevanceBand,
            framing: framing,
          )) {
        return _finish(
          trackAnalytics: trackAnalytics,
          source: source,
          entryCount: entryCount,
          cardType: cardType,
          intent: intent,
          decision: MemoryGovernanceDecision(
            allowed: true,
            decisionId: MemoryGovernanceDecisionId.allowedSameThread,
            reasonId: framing.frame.reasonId,
            currentIntent: intent,
            relevanceBand: relevanceBand,
            requiresUserConfirmation: false,
            reliability: reliability,
          ),
          event: ActivationFunnelAnalytics.memoryGovernanceAllowed,
        );
      }
    }

    // Same pack when pack-bound and policy allows.
    if (intent == CurrentIntent.packBound ||
        ArchivePackScopePolicy.primaryPackId(framing.candidates) != null) {
      if (!ArchivePackScopePolicy.isCrossPack(framing.candidates) ||
          ArchivePackScopePolicy.allowsCrossPackByPolicy(framing.candidates)) {
        if (framing.allowsConnectionClaims &&
            relevanceBand == RelevanceBand.high &&
            CurrentRelevanceGate.candidateMattersNow(
              cardType: cardType,
              records: scopedRecords,
              relevanceBand: relevanceBand,
              framing: framing,
            )) {
          return _finish(
            trackAnalytics: trackAnalytics,
            source: source,
            entryCount: entryCount,
            cardType: cardType,
            intent: intent,
            decision: MemoryGovernanceDecision(
              allowed: true,
              decisionId: MemoryGovernanceDecisionId.allowedSamePack,
              reasonId: framing.frame.reasonId,
              currentIntent: intent,
              relevanceBand: relevanceBand,
              requiresUserConfirmation: false,
              reliability: reliability,
            ),
            event: ActivationFunnelAnalytics.memoryGovernanceAllowed,
          );
        }
      }
    }

    // High relevance still requires authority framing.
    if (relevanceBand == RelevanceBand.high &&
        framing.allowsConnectionClaims &&
        CurrentRelevanceGate.candidateMattersNow(
          cardType: cardType,
          records: scopedRecords,
          relevanceBand: relevanceBand,
          framing: framing,
        )) {
      return _finish(
        trackAnalytics: trackAnalytics,
        source: source,
        entryCount: entryCount,
        cardType: cardType,
        intent: intent,
        decision: MemoryGovernanceDecision(
          allowed: true,
          decisionId: MemoryGovernanceDecisionId.allowedSameThread,
          reasonId: framing.frame.reasonId,
          currentIntent: intent,
          relevanceBand: relevanceBand,
          requiresUserConfirmation: false,
          reliability: reliability,
        ),
        event: ActivationFunnelAnalytics.memoryGovernanceAllowed,
      );
    }

    // Unknown intent — cautious default.
    return _finish(
      trackAnalytics: trackAnalytics,
      source: source,
      entryCount: entryCount,
      cardType: cardType,
      intent: intent,
      decision: MemoryGovernanceDecision(
        allowed: false,
        decisionId: MemoryGovernanceDecisionId.blockedLowRelevance,
        reasonId: 'unknown_intent',
        currentIntent: intent,
        relevanceBand: relevanceBand,
        requiresUserConfirmation: false,
        reliability: reliability,
      ),
      event: ActivationFunnelAnalytics.memoryGovernanceBlocked,
    );
  }

  static bool permitsEngineBuild(MemoryGovernanceDecision decision) =>
      decision.permitsEvidenceBuild &&
      decision.decisionId != MemoryGovernanceDecisionId.blockedMemoryOff &&
      decision.decisionId != MemoryGovernanceDecisionId.blockedFirstSave &&
      decision.decisionId != MemoryGovernanceDecisionId.blockedFreshEntry &&
      decision.decisionId != MemoryGovernanceDecisionId.blockedKeepSeparate;

  static MemoryGovernanceDecision _finish({
    required bool trackAnalytics,
    required String source,
    required int entryCount,
    required MemoryCardType cardType,
    required CurrentIntent intent,
    required MemoryGovernanceDecision decision,
    required String event,
  }) {
    if (trackAnalytics) {
      ActivationFunnelAnalytics.track(
        event,
        cardType: cardType.id,
        decisionId: decision.decisionId,
        reasonId: decision.reasonId,
        currentIntent: intent.id,
        relevanceBand: decision.relevanceBand.id,
        memoryScope: MemoryScopePolicy.scope.id,
        source: source,
        entryCount: entryCount,
      );
    }
    return decision;
  }

  static void resetPersistedState() {
    CurrentIntentSignal.resetSessionState();
    EntryAboutnessSession.resetSessionState();
    MemorySurfacingSession.resetSessionState();
    TopicShiftGuard.resetPersistedState();
  }

  @visibleForTesting
  static void resetForTest() => resetPersistedState();
}