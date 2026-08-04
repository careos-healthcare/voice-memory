import 'package:flutter/material.dart';

import '../../features/archive_packs/cross_pack_confirmation.dart';
import '../../features/memory/cross_thread_confirmation.dart';
import '../../features/memory/memory_authority_framing_engine.dart';
import '../../features/memory/memory_control_model.dart';
import '../../features/memory/memory_governance_decision.dart';
import '../../features/memory/memory_governance_policy.dart';
import '../../features/memory/memory_priority_decision.dart';
import '../../features/memory/memory_priority_governance.dart';
import '../../features/memory/memory_reliability_check.dart';
import '../../features/memory/memory_scope.dart';
import '../../features/memory/memory_scope_policy.dart';
import '../../features/pressure_retention/pressure_check_in_record.dart';
import '../../theme/app_spacing.dart';
import '../archive_packs/cross_pack_confirmation_card.dart';
import 'cross_thread_confirmation_card.dart';
import 'memory_authority_frame_card.dart';
import 'memory_connection_actions_row.dart';
import 'memory_governance_notice.dart';
import 'memory_reliability_badge.dart';
import 'memory_priority_badge.dart';
import 'memory_used_receipt.dart';

/// Evaluates visible-memory state for insight cards.
abstract class MemoryCardVisibilityGate {
  MemoryCardVisibilityGate._();

  static MemoryGovernanceDecision? evaluateGovernance({
    required MemoryCardType cardType,
    required bool memoryUsed,
    required int entryCount,
    List<PressureCheckInRecord> records = const [],
    String source = 'memory_card',
  }) {
    if (!memoryUsed || entryCount < 1) return null;
    if (MemoryScopePolicy.scope == MemoryScope.off) return null;

    final candidates = records.isNotEmpty
        ? records
        : MemoryAuthorityFrameLog.candidatesFor(cardType);
    if (candidates.isEmpty && records.isEmpty) return null;

    return MemoryGovernancePolicy.evaluate(
      cardType: cardType,
      records: candidates,
      entryCount: entryCount,
      source: source,
    );
  }

  static MemoryPriorityDecision? evaluatePriority({
    required MemoryCardType cardType,
    required bool memoryUsed,
    required int entryCount,
    MemoryGovernanceDecision? governance,
    List<PressureCheckInRecord> records = const [],
    String source = 'memory_card',
  }) {
    final gov =
        governance ??
        evaluateGovernance(
          cardType: cardType,
          memoryUsed: memoryUsed,
          entryCount: entryCount,
          records: records,
          source: source,
        );
    if (gov == null) return null;
    final candidates = records.isNotEmpty
        ? records
        : MemoryAuthorityFrameLog.candidatesFor(cardType);
    return MemoryPriorityGovernance.evaluate(
      cardType: cardType,
      records: candidates.isNotEmpty ? candidates : records,
      governance: gov,
      entryCount: entryCount,
      source: source,
    );
  }

  static MemoryReliabilityResult? evaluate({
    required MemoryCardType cardType,
    required bool memoryUsed,
    required int entryCount,
    List<PressureCheckInRecord> records = const [],
  }) => evaluateGovernance(
    cardType: cardType,
    memoryUsed: memoryUsed,
    entryCount: entryCount,
    records: records,
  )?.reliability;

  static bool blocksStrongClaim({
    required MemoryCardType cardType,
    required bool memoryUsed,
    required int entryCount,
    MemoryGovernanceDecision? governance,
    MemoryPriorityDecision? priority,
    MemoryReliabilityResult? reliability,
    List<PressureCheckInRecord> records = const [],
  }) {
    final decision =
        governance ??
        evaluateGovernance(
          cardType: cardType,
          memoryUsed: memoryUsed,
          entryCount: entryCount,
          records: records,
        );
    if (decision == null) return true;
    final pri =
        priority ??
        evaluatePriority(
          cardType: cardType,
          memoryUsed: memoryUsed,
          entryCount: entryCount,
          governance: decision,
          records: records,
        );
    if (pri == null || !pri.canSupportClaim) return true;
    if (!decision.allowsMemoryClaim) return true;
    final rel = reliability ?? decision.reliability;
    if (rel == null) return true;
    return CrossThreadConfirmation.needsConfirmation(rel, cardType) ||
        CrossPackConfirmation.needsConfirmation(
          cardTypeId: cardType.id,
          isCrossPack: rel.state == MemoryReliabilityState.crossPack,
          allowedByPolicy: false,
        );
  }
}

/// Receipt, reliability badge, cross-thread gate, and action row for
/// memory-used insight cards.
class MemoryCardVisibilityControls extends StatefulWidget {
  const MemoryCardVisibilityControls({
    super.key,
    required this.cardType,
    required this.memoryUsed,
    this.entryCount = 1,
    this.records = const [],
    this.reliability,
    this.governance,
    this.priority,
    this.showCrossThreadGate = false,
  });

  final MemoryCardType cardType;
  final bool memoryUsed;
  final int entryCount;
  final List<PressureCheckInRecord> records;
  final MemoryReliabilityResult? reliability;
  final MemoryGovernanceDecision? governance;
  final MemoryPriorityDecision? priority;
  final bool showCrossThreadGate;

  @override
  State<MemoryCardVisibilityControls> createState() =>
      _MemoryCardVisibilityControlsState();
}

class _MemoryCardVisibilityControlsState
    extends State<MemoryCardVisibilityControls> {
  MemoryGovernanceDecision? get _governance =>
      widget.governance ??
      MemoryCardVisibilityGate.evaluateGovernance(
        cardType: widget.cardType,
        memoryUsed: widget.memoryUsed,
        entryCount: widget.entryCount,
        records: widget.records,
      );

  MemoryReliabilityResult? get _reliability =>
      widget.reliability ?? _governance?.reliability;

  MemoryPriorityDecision? get _priority =>
      widget.priority ??
      MemoryCardVisibilityGate.evaluatePriority(
        cardType: widget.cardType,
        memoryUsed: widget.memoryUsed,
        entryCount: widget.entryCount,
        records: widget.records,
        governance: _governance,
      );

  @override
  Widget build(BuildContext context) {
    final governance = _governance;
    final priority = _priority;
    final reliability = _reliability;
    if (governance == null || reliability == null || priority == null) {
      return const SizedBox.shrink();
    }

    if (widget.showCrossThreadGate &&
        governance.decisionId ==
            MemoryGovernanceDecisionId.confirmCrossThread &&
        CrossThreadConfirmation.needsConfirmation(
          reliability,
          widget.cardType,
        )) {
      return CrossThreadConfirmationCard(
        cardType: widget.cardType,
        onChanged: () => setState(() {}),
      );
    }

    if (widget.showCrossThreadGate &&
        governance.decisionId == MemoryGovernanceDecisionId.confirmCrossPack &&
        CrossPackConfirmation.needsConfirmation(
          cardTypeId: widget.cardType.id,
          isCrossPack: reliability.state == MemoryReliabilityState.crossPack,
          allowedByPolicy: false,
        )) {
      return CrossPackConfirmationCard(
        cardType: widget.cardType,
        onChanged: () => setState(() {}),
      );
    }

    if (!governance.allowsMemoryClaim || !priority.canSupportClaim) {
      if (governance.showBackgroundOnly || priority.backgroundOnly) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MemoryGovernanceNotice(backgroundOnly: true),
            MemoryPriorityBadge(priority: priority),
          ],
        );
      }
      if (governance.showGovernanceNotice && widget.entryCount > 1) {
        return const MemoryGovernanceNotice();
      }
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MemoryUsedReceipt(
          cardType: widget.cardType,
          memoryUsed: widget.memoryUsed,
          entryCount: widget.entryCount,
          governance: governance,
          priority: priority,
        ),
        MemoryPriorityBadge(priority: priority),
        MemoryReliabilityBadge(
          state: reliability.state,
          cardType: widget.cardType.id,
        ),
        const SizedBox(height: AppSpacing.xs),
        MemoryAuthorityFrameCard(cardType: widget.cardType),
        MemoryConnectionActionsRow(
          cardType: widget.cardType,
          onChanged: () => setState(() {}),
        ),
      ],
    );
  }
}
