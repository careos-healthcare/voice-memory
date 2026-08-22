import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

/// One-shot "fresh next entry" — the next save carries treat-as-new
/// metadata without changing global memory scope.
abstract class NextEntryFreshMode {
  NextEntryFreshMode._();

  static bool enabledForNextSave = false;

  static bool get isRelevant => MemoryScopePolicy.scope != MemoryScope.off;

  static void enable() {
    if (!isRelevant) return;
    enabledForNextSave = true;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.freshNextEntryEnabled,
      memoryScope: MemoryScopePolicy.scope.id,
    );
  }

  static void cancel() {
    enabledForNextSave = false;
  }

  /// Consumes the flag at save time. Returns whether this save is fresh.
  static bool consumeForSave() {
    if (!enabledForNextSave) return false;
    enabledForNextSave = false;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.freshNextEntryApplied,
      memoryScope: MemoryScopePolicy.scope.id,
    );
    return true;
  }

  @visibleForTesting
  static void resetForTest() {
    enabledForNextSave = false;
  }
}