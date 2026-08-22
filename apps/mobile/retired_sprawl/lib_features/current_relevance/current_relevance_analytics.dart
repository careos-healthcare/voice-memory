import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/current_relevance/current_relevance_model.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

/// Safe analytics for current relevance — metadata only, no journal text.
abstract final class CurrentRelevanceAnalytics {
  CurrentRelevanceAnalytics._();

  static const seenEvent = 'current_relevance_seen';
  static const answeredEvent = 'current_relevance_answered';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String source,
    required int entryCount,
    required bool hasConfirmedRepeat,
  }) {
    _emit(
      seenEvent,
      source: source,
      entryCount: entryCount,
      answerType: null,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }

  static void answered({
    required String source,
    required int entryCount,
    required CurrentRelevanceAnswer answer,
    required bool hasConfirmedRepeat,
  }) {
    _emit(
      answeredEvent,
      source: source,
      entryCount: entryCount,
      answerType: answer.analyticsValue,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    required String? answerType,
    required bool hasConfirmedRepeat,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'has_confirmed_repeat': hasConfirmedRepeat ? 1 : 0,
      'answer_type': ?answerType,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      answer: answerType,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_CURRENT_RELEVANCE event=$event source=$source '
        'entry_count=$entryCount answer_type=$answerType '
        'has_confirmed_repeat=$hasConfirmedRepeat',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}