import '../../services/activation_funnel_analytics.dart';

/// Safe analytics for transcript correction — no user text.
abstract final class TranscriptCorrectionAnalytics {
  TranscriptCorrectionAnalytics._();

  static const openedEvent = 'transcript_correction_opened';
  static const savedEvent = 'transcript_correction_saved';
  static const failedEvent = 'transcript_correction_failed';
  static const reason = 'transcript_correction';

  static void opened({
    required String source,
    required int entryCount,
    required bool hasParentEntry,
  }) {
    _track(
      openedEvent,
      source: source,
      entryCount: entryCount,
      hasParentEntry: hasParentEntry,
    );
  }

  static void saved({
    required String source,
    required int entryCount,
    required bool hasParentEntry,
  }) {
    _track(
      savedEvent,
      source: source,
      entryCount: entryCount,
      hasParentEntry: hasParentEntry,
    );
  }

  static void failed({
    required String source,
    required int entryCount,
    required bool hasParentEntry,
  }) {
    _track(
      failedEvent,
      source: source,
      entryCount: entryCount,
      hasParentEntry: hasParentEntry,
    );
  }

  static void _track(
    String event, {
    required String source,
    required int entryCount,
    required bool hasParentEntry,
  }) {
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      hasParentEntry: hasParentEntry,
      reason: reason,
    );
  }
}
