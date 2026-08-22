import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/second_moment_return/second_moment_return_model.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

/// Safe metadata analytics for second-moment return — no journal text.
abstract final class SecondMomentReturnAnalytics {
  SecondMomentReturnAnalytics._();

  static const seenEvent = 'second_moment_return_seen';
  static const actionTappedEvent = 'second_moment_return_action_tapped';
  static const promptTappedEvent = 'second_moment_return_prompt_tapped';
  static const dismissedTodayEvent = 'second_moment_return_dismissed_today';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({required SecondMomentReturnResult result}) {
    _emit(
      seenEvent,
      source: result.source,
      entryCount: result.entryCount,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
      actionType: null,
      promptType: null,
    );
  }

  static void actionTapped({
    required SecondMomentReturnResult result,
    required SecondMomentReturnActionType actionType,
  }) {
    _emit(
      actionTappedEvent,
      source: result.source,
      entryCount: result.entryCount,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
      actionType: actionType,
      promptType: null,
    );
  }

  static void promptTapped({
    required SecondMomentReturnResult result,
    required SecondMomentReturnPromptType promptType,
  }) {
    _emit(
      promptTappedEvent,
      source: result.source,
      entryCount: result.entryCount,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
      actionType: null,
      promptType: promptType,
    );
  }

  static void dismissedToday({required SecondMomentReturnResult result}) {
    _emit(
      dismissedTodayEvent,
      source: result.source,
      entryCount: result.entryCount,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
      actionType: SecondMomentReturnActionType.notToday,
      promptType: null,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    required bool hasConfirmedRepeat,
    required SecondMomentReturnActionType? actionType,
    required SecondMomentReturnPromptType? promptType,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'has_confirmed_repeat': hasConfirmedRepeat ? 1 : 0,
      if (actionType != null) 'action_type': actionType.name,
      if (promptType != null) 'prompt_type': promptType.name,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_SECOND_MOMENT_RETURN event=$event source=$source '
        'entry_count=$entryCount has_confirmed_repeat=$hasConfirmedRepeat '
        'action_type=${actionType?.name} prompt_type=${promptType?.name}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}