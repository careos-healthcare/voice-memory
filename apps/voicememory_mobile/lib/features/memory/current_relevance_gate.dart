import '../archive_packs/archive_pack_scope_policy.dart';
import '../pressure_retention/pressure_check_in_record.dart';
import 'archive_retrieval_policy.dart';
import 'cross_thread_confirmation.dart';
import '../archive_packs/cross_pack_confirmation.dart';
import 'memory_authority_framing_engine.dart';
import 'memory_authority_frame.dart';
import 'memory_control_model.dart';
import 'memory_governance_decision.dart';
import 'memory_reliability_check.dart';
import 'memory_scope.dart';
import 'memory_scope_policy.dart';
import 'wrong_thread_feedback.dart';

/// "Does this matter right now?" — relevance from retrieval + authority.
abstract class CurrentRelevanceGate {
  CurrentRelevanceGate._();

  static RelevanceBand band({
    required MemoryCardType cardType,
    required List<PressureCheckInRecord> records,
    required MemoryReliabilityResult reliability,
    DateTime? now,
  }) {
    if (MemoryScopePolicy.scope == MemoryScope.off) {
      return RelevanceBand.none;
    }

    final retrieval = ArchiveRetrievalPolicy.retrieve(
      records,
      now: now,
      cardType: cardType.id,
    );
    if (retrieval.isEmpty || !retrieval.supportsConnectionClaims) {
      return RelevanceBand.low;
    }

    return switch (reliability.state) {
      MemoryReliabilityState.blocked ||
      MemoryReliabilityState.lowEvidence => RelevanceBand.low,
      MemoryReliabilityState.mixedEvidence ||
      MemoryReliabilityState.staleEvidence ||
      MemoryReliabilityState.crossThread ||
      MemoryReliabilityState.crossPack => RelevanceBand.medium,
      MemoryReliabilityState.enoughEvidence => RelevanceBand.high,
    };
  }

  /// Whether a candidate can matter now under governance rules.
  static bool candidateMattersNow({
    required MemoryCardType cardType,
    required List<PressureCheckInRecord> records,
    required RelevanceBand relevanceBand,
    required MemoryAuthorityFraming framing,
  }) {
    if (relevanceBand == RelevanceBand.none ||
        relevanceBand == RelevanceBand.low) {
      return false;
    }

    final candidates = framing.candidates;
    if (candidates.isEmpty) return false;

    if (framing.frame.authorityState == MemoryAuthorityState.confirmed ||
        candidates.any((r) => r.connectionApproved) ||
        CrossThreadConfirmation.isApproved(cardType) ||
        CrossPackConfirmation.isApproved(cardType.id)) {
      return true;
    }

    final explicitThread = WrongThreadFeedback.explicitThreadFor(cardType);
    if (explicitThread != null) {
      return candidates.every((r) => r.archiveThreadId == explicitThread);
    }

    if (ArchivePackScopePolicy.isCrossPack(candidates)) {
      return ArchivePackScopePolicy.allowsCrossPackByPolicy(candidates) ||
          CrossPackConfirmation.isApproved(cardType.id);
    }

    if (CrossThreadDetector.isCrossThread(candidates)) {
      return CrossThreadConfirmation.isApproved(cardType);
    }

    if (relevanceBand == RelevanceBand.high && framing.allowsConnectionClaims) {
      return true;
    }

    return relevanceBand == RelevanceBand.medium &&
        framing.allowsConnectionClaims;
  }
}
