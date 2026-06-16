import 'memory_control_model.dart';
import 'memory_governance_decision.dart';
import 'memory_priority_decision.dart';
import 'memory_scope.dart';
import 'memory_scope_policy.dart';

/// When the visible "Used archive context" receipt may render.
abstract class MemoryVisibilityReceipt {
  MemoryVisibilityReceipt._();

  static bool shouldShow({
    required MemoryCardType cardType,
    required bool memoryUsed,
    required int entryCount,
    MemoryGovernanceDecision? governance,
    MemoryPriorityDecision? priority,
  }) {
    if (!memoryUsed) return false;
    if (entryCount < 1) return false;
    if (MemoryScopePolicy.scope == MemoryScope.off) return false;
    if (priority != null && !priority.canSupportClaim) return false;
    if (governance != null) return governance.showReceipt;
    return false;
  }
}
