import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_reliability_check.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/memory/wrong_thread_feedback.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

/// Cross-thread confirmation — user must approve before a strong claim
/// spans two explicit archive threads.
abstract class CrossThreadConfirmation {
  CrossThreadConfirmation._();

  static final Set<String> _approvedCardTypes = <String>{};

  static bool isApproved(MemoryCardType cardType) =>
      _approvedCardTypes.contains(cardType.id);

  static bool needsConfirmation(
    MemoryReliabilityResult reliability,
    MemoryCardType cardType,
  ) => reliability.requiresCrossThreadConfirmation && !isApproved(cardType);

  static void approve(MemoryCardType cardType) {
    _approvedCardTypes.add(cardType.id);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.crossThreadConnectionConfirmed,
      cardType: cardType.id,
      memoryScope: MemoryScopePolicy.scope.id,
    );
  }

  static void keepSeparate(MemoryCardType cardType, {String? threadId}) {
    WrongThreadFeedback.keepSeparate(cardType, threadId: threadId);
  }

  @visibleForTesting
  static void resetForTest() {
    _approvedCardTypes.clear();
  }
}