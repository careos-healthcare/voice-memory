import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'proof_specificity_boost_copy.dart';
import 'proof_specificity_boost_model.dart';

/// Safe metadata analytics for proof specificity boost — no journal text.
abstract final class ProofSpecificityBoostAnalytics {
  ProofSpecificityBoostAnalytics._();

  static const seenEvent = 'proof_specificity_boost_seen';
  static const answeredEvent = 'proof_specificity_boost_answered';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({
    required String source,
    required ProofSpecificityBoostSurface surface,
    required ProofSpecificityBoostResult result,
  }) {
    _emit(
      seenEvent,
      source: source,
      surface: surface,
      answerType: null,
      entryCount: result.entryCount,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
      hasSafeAnchor: result.hasSafeAnchor,
    );
  }

  static void answered({
    required String source,
    required ProofSpecificityBoostSurface surface,
    required ProofSpecificityBoostAnswerType answerType,
    required ProofSpecificityBoostResult result,
  }) {
    _emit(
      answeredEvent,
      source: source,
      surface: surface,
      answerType: answerType,
      entryCount: result.entryCount,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
      hasSafeAnchor: result.hasSafeAnchor,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required ProofSpecificityBoostSurface surface,
    required ProofSpecificityBoostAnswerType? answerType,
    required int entryCount,
    required bool hasConfirmedRepeat,
    required bool hasSafeAnchor,
  }) {
    final props = <String, Object>{
      'source': source,
      'surface': surface.analyticsValue,
      'entry_count': entryCount,
      'has_confirmed_repeat': hasConfirmedRepeat ? 1 : 0,
      'has_safe_anchor': hasSafeAnchor ? 1 : 0,
      if (answerType != null) 'answer_type': answerType.analyticsValue,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PROOF_SPECIFICITY_BOOST event=$event source=$source '
        'surface=${surface.analyticsValue} answer_type='
        '${answerType?.analyticsValue ?? 'none'} entry_count=$entryCount '
        'has_confirmed_repeat=$hasConfirmedRepeat '
        'has_safe_anchor=$hasSafeAnchor',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
