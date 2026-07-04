import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/beta_activation/beta_activation_summary_tracker.dart';

/// Safe analytics for weekly archive review — metadata only.
abstract final class WeeklyArchiveWeekReviewAnalytics {
  WeeklyArchiveWeekReviewAnalytics._();

  static const seenEvent = 'weekly_archive_week_review_seen';
  static const recordTappedEvent = 'weekly_archive_week_review_record_tapped';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({
    required String surface,
    required int entryCount,
    required bool hasRepeat,
    required bool hasChange,
    required bool hasPositivePattern,
  }) {
    _emit(
      seenEvent,
      surface: surface,
      entryCount: entryCount,
      hasRepeat: hasRepeat,
      hasChange: hasChange,
      hasPositivePattern: hasPositivePattern,
    );
  }

  static void recordTapped({
    required String surface,
    required int entryCount,
    required bool hasRepeat,
    required bool hasChange,
    required bool hasPositivePattern,
  }) {
    _emit(
      recordTappedEvent,
      surface: surface,
      entryCount: entryCount,
      hasRepeat: hasRepeat,
      hasChange: hasChange,
      hasPositivePattern: hasPositivePattern,
    );
  }

  static void _emit(
    String event, {
    required String surface,
    required int entryCount,
    required bool hasRepeat,
    required bool hasChange,
    required bool hasPositivePattern,
  }) {
    final props = <String, Object>{
      'surface': surface,
      'entry_count': entryCount,
      'has_repeat': hasRepeat,
      'has_change': hasChange,
      'has_positive_pattern': hasPositivePattern,
    };
    captureForTest?.call(event, props);
    if (event == seenEvent) {
      unawaited(BetaActivationSummaryTracker.trackWeeklyReviewOpened());
    }
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_WEEKLY_REVIEW event=$event surface=$surface '
        'entry_count=$entryCount has_repeat=$hasRepeat '
        'has_change=$hasChange has_positive_pattern=$hasPositivePattern',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
