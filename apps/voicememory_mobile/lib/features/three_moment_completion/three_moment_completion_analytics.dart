import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'three_moment_completion_model.dart';

/// Metadata-only analytics for three-moment completion guidance.
abstract final class ThreeMomentCompletionAnalytics {
  ThreeMomentCompletionAnalytics._();

  static const seenEvent = 'three_moment_completion_seen';
  static const ctaTappedEvent = 'three_moment_completion_cta_tapped';
  static const dismissedTodayEvent = 'three_moment_completion_dismissed_today';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({required ThreeMomentCompletionResult result}) {
    _emit(
      seenEvent,
      source: result.source,
      entryCount: result.entryCount,
      stage: result.stage,
    );
  }

  static void ctaTapped({
    required ThreeMomentCompletionResult result,
    required ThreeMomentCompletionActionType actionType,
  }) {
    _emit(
      ctaTappedEvent,
      source: result.source,
      entryCount: result.entryCount,
      stage: result.stage,
      actionType: actionType,
    );
  }

  static void dismissedToday({required ThreeMomentCompletionResult result}) {
    _emit(
      dismissedTodayEvent,
      source: result.source,
      entryCount: result.entryCount,
      stage: result.stage,
      actionType: ThreeMomentCompletionActionType.notToday,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    required ThreeMomentCompletionStage stage,
    ThreeMomentCompletionActionType? actionType,
  }) {
    final properties = <String, Object>{
      'entry_count': entryCount,
      'source': source,
      'stage': stage.analyticsValue,
      if (actionType != null) 'action_type': actionType.analyticsValue,
    };

    captureForTest?.call(event, properties);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_THREE_MOMENT_COMPLETION event=$event source=$source '
        'entry_count=$entryCount stage=${stage.analyticsValue} '
        'action_type=${actionType?.analyticsValue ?? 'none'}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
