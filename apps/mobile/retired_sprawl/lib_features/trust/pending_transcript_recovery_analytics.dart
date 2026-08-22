import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';

/// Safe analytics for pending-transcript recovery — no user text.
abstract final class PendingTranscriptRecoveryAnalytics {
  PendingTranscriptRecoveryAnalytics._();

  static const openedEvent = 'pending_transcript_recovery_opened';
  static const savedEvent = 'pending_transcript_recovery_saved';
  static const failedEvent = 'pending_transcript_recovery_failed';
  static const reason = 'pending_transcript';

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