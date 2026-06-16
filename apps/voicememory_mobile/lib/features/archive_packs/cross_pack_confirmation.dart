import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import '../memory/memory_scope.dart';
import '../memory/memory_scope_policy.dart';
import 'archive_pack_scope_policy.dart';

/// Cross-pack confirmation — user must approve before a strong claim
/// spans two archive packs.
abstract class CrossPackConfirmation {
  CrossPackConfirmation._();

  static final Set<String> _approvedCardTypes = <String>{};
  static final Set<String> _sessionSuppressed = <String>{};

  static bool isSessionSuppressed(String cardTypeId) =>
      _sessionSuppressed.contains(cardTypeId);

  static bool isApproved(String cardTypeId) =>
      _approvedCardTypes.contains(cardTypeId);

  static bool needsConfirmation({
    required String cardTypeId,
    required bool isCrossPack,
    required bool allowedByPolicy,
  }) => isCrossPack && !allowedByPolicy && !isApproved(cardTypeId);

  static void approve(String cardTypeId) {
    _approvedCardTypes.add(cardTypeId);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.crossPackConnectionConfirmed,
      cardType: cardTypeId,
      memoryScope: MemoryScopePolicy.scope.id,
    );
  }

  static void keepSeparate(String cardTypeId) {
    _sessionSuppressed.add(cardTypeId);
    _approvedCardTypes.remove(cardTypeId);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.crossPackConnectionKeptSeparate,
      cardType: cardTypeId,
      memoryScope: MemoryScopePolicy.scope.id,
    );
  }

  @visibleForTesting
  static void resetForTest() {
    _approvedCardTypes.clear();
    _sessionSuppressed.clear();
  }
}
