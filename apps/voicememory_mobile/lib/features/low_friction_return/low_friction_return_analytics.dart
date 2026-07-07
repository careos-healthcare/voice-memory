import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'low_friction_return_model.dart';

/// Safe analytics for low-friction return prompts — metadata only.
abstract final class LowFrictionReturnAnalytics {
  LowFrictionReturnAnalytics._();

  static const seenEvent = 'low_friction_return_seen';
  static const actionTappedEvent = 'low_friction_return_action_tapped';
  static const promptSelectedEvent = 'low_friction_return_prompt_selected';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({
    required String source,
    required int entryCount,
  }) {
    _emit(
      seenEvent,
      source: source,
      entryCount: entryCount,
      actionType: null,
      promptType: null,
    );
  }

  static void actionTapped({
    required String source,
    required int entryCount,
    required LowFrictionReturnActionType actionType,
  }) {
    _emit(
      actionTappedEvent,
      source: source,
      entryCount: entryCount,
      actionType: actionType,
      promptType: null,
    );
  }

  static void promptSelected({
    required String source,
    required int entryCount,
    required LowFrictionReturnPromptType promptType,
  }) {
    _emit(
      promptSelectedEvent,
      source: source,
      entryCount: entryCount,
      actionType: null,
      promptType: promptType,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    required LowFrictionReturnActionType? actionType,
    required LowFrictionReturnPromptType? promptType,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      if (actionType != null) 'action_type': actionType.analyticsValue,
      if (promptType != null) 'prompt_type': promptType.analyticsValue,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_LOW_FRICTION_RETURN event=$event source=$source '
        'entry_count=$entryCount action_type=${actionType?.analyticsValue ?? 'none'} '
        'prompt_type=${promptType?.analyticsValue ?? 'none'}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
