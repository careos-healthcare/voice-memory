import 'package:archiveme_mobile/features/aha/aha_moment_candidate.dart';
import 'package:archiveme_mobile/features/aha/aha_moment_store.dart';
import 'package:archiveme_mobile/features/memory/memory_authority_framing_engine.dart';
import 'package:archiveme_mobile/features/memory/memory_connection_rules.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_control_store.dart';
import 'package:archiveme_mobile/features/memory/memory_governance_policy.dart';
import 'package:archiveme_mobile/features/memory/memory_priority_decision.dart';
import 'package:archiveme_mobile/features/memory/memory_priority_governance.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/memory/not_important_feedback.dart';
import 'package:archiveme_mobile/features/memory/wrong_thread_feedback.dart';
import 'package:archiveme_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/weekly_thread_review_engine.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';

/// Finds the first honest archive "aha" moment when governance allows it.
///
/// Pure and deterministic — reuses the thread-return memory pipeline without
/// inventing new claims. Never overrides Memory Scope, Governance, or Priority.
class AhaMomentEngine {
  const AhaMomentEngine();

  static const MemoryCardType _cardType = AhaMomentCandidate.underlyingCardType;

  /// Whether a stronger memory card would render on the current surface.
  static bool hasStrongerMemoryCard({
    required List<PressureCheckInRecord> records,
    int? entryCount,
    DateTime? now,
  }) {
    final count = entryCount ?? records.length;
    if (const ThreadReturnEvidenceEngine()
        .build(records, now: now, entryCount: count)
        .hasEvidence) {
      return true;
    }
    if (const BeliefDistanceEngine()
        .build(records, entryCount: count)
        .hasBelief) {
      return true;
    }
    if (const WeeklyThreadReviewEngine().build(records, now: now).hasReview) {
      return true;
    }
    return false;
  }

  AhaMomentCandidate? evaluate({
    required List<PressureCheckInRecord> records,
    required int entryCount,
    DateTime? now,
    bool hasStrongerMemoryCardVisible = false,
    bool trackAnalytics = true,
    String source = 'aha_engine',
  }) {
    if (hasStrongerMemoryCardVisible) return null;
    if (AhaMomentStore.firstAhaCompleted) return null;
    if (AhaMomentSession.hidden) return null;
    if (MemoryScopePolicy.scope == MemoryScope.off) return null;
    if (entryCount < 2) return null;

    if (MemoryControlStore.isSuppressed(_cardType) ||
        WrongThreadFeedback.isSessionSuppressed(_cardType) ||
        NotImportantFeedback.isDemoted(_cardType)) {
      return null;
    }

    if (records.any((r) => r.treatAsNew || r.keepSeparate)) {
      return null;
    }

    final governance = MemoryGovernancePolicy.evaluate(
      cardType: _cardType,
      records: records,
      entryCount: entryCount,
      now: now,
      source: source,
      trackAnalytics: trackAnalytics,
    );
    if (!MemoryGovernancePolicy.permitsEngineBuild(governance)) {
      return null;
    }

    final framing = const MemoryAuthorityFramingEngine().frame(
      records,
      now: now,
      cardType: _cardType,
    );
    if (!framing.allowsConnectionClaims) return null;

    final priority = MemoryPriorityGovernance.evaluate(
      cardType: _cardType,
      records: records,
      governance: governance,
      framing: framing,
      now: now,
      entryCount: entryCount,
      source: source,
      trackAnalytics: trackAnalytics,
    );
    if (priority.shouldSuppress ||
        !priority.priorityBand.canSupportMajorClaim) {
      return null;
    }

    final eligible = MemoryPriorityGovernance.filterCandidates(
      framing.candidates,
      cardType: _cardType,
      priority: priority,
      anchor: now,
      confirmationPending: governance.requiresUserConfirmation,
    );

    if (eligible.isEmpty) return null;

    final userConfirmed =
        MemoryConnectionRules.isConfirmed(_cardType.id) ||
        eligible.any((r) => r.connectionApproved);

    if (eligible.length < 2 && !userConfirmed) return null;

    if (eligible.any((r) => r.treatAsNew || r.keepSeparate)) return null;

    final candidate = AhaMomentCandidate(
      entryCount: entryCount,
      eligibleEntryCount: eligible.length,
      memoryScope: MemoryScopePolicy.scope.id,
      priorityBand: priority.priorityBand.id,
      authorityState: framing.frame.authorityState,
      useCautiousCopy:
          framing.frame.requiresCautiousCopy ||
          priority.safeExplanationId ==
              MemoryPriorityExplanationId.mixedCautious,
      source: source,
    );

    if (trackAnalytics) {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.ahaMomentCandidateFound,
        cardType: AhaMomentCardType.id,
        entryCount: entryCount,
        memoryScope: candidate.memoryScope,
        priorityBand: candidate.priorityBand,
        authorityState: candidate.authorityStateId,
        source: source,
        oncePerSession: true,
      );
    }

    return candidate;
  }
}

/// Visibility gates for the first-aha card on a screen.
abstract class AhaMomentGates {
  AhaMomentGates._();

  static bool shouldShow({
    required AhaMomentCandidate? candidate,
    required int entryCount,
  }) =>
      candidate != null &&
      entryCount >= 2 &&
      !AhaMomentStore.firstAhaCompleted &&
      !AhaMomentSession.hidden;
}