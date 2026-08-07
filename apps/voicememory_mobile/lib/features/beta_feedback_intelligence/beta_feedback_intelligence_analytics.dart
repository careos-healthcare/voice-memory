import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'beta_feedback_intelligence_model.dart';

/// Metadata-only analytics for beta feedback intelligence.
abstract final class BetaFeedbackIntelligenceAnalytics {
  BetaFeedbackIntelligenceAnalytics._();

  static const seenEvent = 'beta_feedback_intelligence_seen';
  static const openedEvent = 'beta_feedback_intelligence_opened';
  static const submittedEvent = 'beta_feedback_intelligence_submitted';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String source,
    required int entryCount,
    required bool reachedFirstProof,
    required bool sawProBridge,
  }) {
    _emit(
      seenEvent,
      source: source,
      entryCount: entryCount,
      reachedFirstProof: reachedFirstProof,
      sawProBridge: sawProBridge,
    );
  }

  static void opened({
    required String source,
    required int entryCount,
    required bool reachedFirstProof,
    required bool sawProBridge,
  }) {
    _emit(
      openedEvent,
      source: source,
      entryCount: entryCount,
      reachedFirstProof: reachedFirstProof,
      sawProBridge: sawProBridge,
    );
  }

  static void submitted({
    required String source,
    required int entryCount,
    required bool reachedFirstProof,
    required bool sawProBridge,
    required BetaChatGptDifferenceAnswer chatGptDifferenceAnswer,
    required BetaWouldPayAnswer wouldPayAnswer,
    required BetaMainConfusionBucket mainConfusionBucket,
    required BetaStrongestMomentBucket strongestMomentBucket,
  }) {
    _emit(
      submittedEvent,
      source: source,
      entryCount: entryCount,
      reachedFirstProof: reachedFirstProof,
      sawProBridge: sawProBridge,
      chatGptDifferenceAnswer: chatGptDifferenceAnswer,
      wouldPayAnswer: wouldPayAnswer,
      mainConfusionBucket: mainConfusionBucket,
      strongestMomentBucket: strongestMomentBucket,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    required bool reachedFirstProof,
    required bool sawProBridge,
    BetaChatGptDifferenceAnswer? chatGptDifferenceAnswer,
    BetaWouldPayAnswer? wouldPayAnswer,
    BetaMainConfusionBucket? mainConfusionBucket,
    BetaStrongestMomentBucket? strongestMomentBucket,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'reached_first_proof': reachedFirstProof ? 1 : 0,
      'saw_pro_bridge': sawProBridge ? 1 : 0,
      if (chatGptDifferenceAnswer != null)
        'chatgpt_difference_answer': _chatGptParam(chatGptDifferenceAnswer),
      if (wouldPayAnswer != null)
        'would_pay_answer': _wouldPayParam(wouldPayAnswer),
      if (mainConfusionBucket != null)
        'main_confusion_bucket': mainConfusionBucket.name,
      if (strongestMomentBucket != null)
        'strongest_moment_bucket': strongestMomentBucket.name,
    };

    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_BETA_FEEDBACK_INTELLIGENCE event=$event source=$source '
        'entry_count=$entryCount reached_first_proof=${props['reached_first_proof']} '
        'saw_pro_bridge=${props['saw_pro_bridge']}',
      );
    }
  }

  static String _chatGptParam(BetaChatGptDifferenceAnswer answer) {
    return switch (answer) {
      BetaChatGptDifferenceAnswer.yes => 'yes',
      BetaChatGptDifferenceAnswer.notSure => 'not_sure',
      BetaChatGptDifferenceAnswer.no => 'no',
    };
  }

  static String _wouldPayParam(BetaWouldPayAnswer answer) {
    return switch (answer) {
      BetaWouldPayAnswer.yes => 'yes',
      BetaWouldPayAnswer.maybe => 'maybe',
      BetaWouldPayAnswer.no => 'no',
    };
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
