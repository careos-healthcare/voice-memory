import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

/// Safe analytics for Come Back Tomorrow v2 — metadata only, no phrase text.
abstract final class ComeBackTomorrowV2Analytics {
  ComeBackTomorrowV2Analytics._();

  static const watchSetEvent = 'come_back_tomorrow_watch_set';
  static const questionSeenEvent = 'come_back_tomorrow_question_seen';
  static const answeredEvent = 'come_back_tomorrow_answered';
  static const quietSignalSeenEvent = 'come_back_tomorrow_quiet_signal_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void watchSet({
    required String source,
    required int entryCount,
    required bool hasWatchTarget,
  }) {
    _emit(
      watchSetEvent,
      source: source,
      entryCount: entryCount,
      hasWatchTarget: hasWatchTarget,
    );
  }

  static void questionSeen({
    required String source,
    required int entryCount,
    required int daysSinceSet,
  }) {
    _emit(
      questionSeenEvent,
      source: source,
      entryCount: entryCount,
      daysSinceSet: daysSinceSet,
    );
  }

  static void answered({
    required String source,
    required int entryCount,
    required String answerType,
  }) {
    _emit(
      answeredEvent,
      source: source,
      entryCount: entryCount,
      answerType: answerType,
    );
  }

  static void quietSignalSeen({
    required String source,
    required int entryCount,
    required int daysSinceSet,
  }) {
    _emit(
      quietSignalSeenEvent,
      source: source,
      entryCount: entryCount,
      daysSinceSet: daysSinceSet,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    bool? hasWatchTarget,
    int? daysSinceSet,
    String? answerType,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      if (hasWatchTarget != null) 'has_watch_target': hasWatchTarget ? 1 : 0,
      'days_since_set': ?daysSinceSet,
      'answer_type': ?answerType,
    };

    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      hasWatchTarget: hasWatchTarget,
      daysSinceSet: daysSinceSet,
      answerType: answerType,
    );
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_COME_BACK_TOMORROW_V2 event=$event source=$source '
        'entry_count=$entryCount '
        '${hasWatchTarget != null ? 'has_watch_target=$hasWatchTarget ' : ''}'
        '${daysSinceSet != null ? 'days_since_set=$daysSinceSet ' : ''}'
        '${answerType != null ? 'answer_type=$answerType' : ''}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}