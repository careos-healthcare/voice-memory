import '../../services/activation_funnel_analytics.dart';

/// Safe analytics when placeholder/pending entries are excluded from evidence.
abstract final class ArchiveEvidenceAnalytics {
  ArchiveEvidenceAnalytics._();

  static const skippedPlaceholderEvent = 'archive_evidence_skipped_placeholder';
  static const skippedPlaceholderReason = 'placeholder_or_pending_transcript';

  static void evidenceSkippedPlaceholder({
    required String source,
    required int entryCount,
  }) {
    if (entryCount <= 0) return;
    ActivationFunnelAnalytics.track(
      skippedPlaceholderEvent,
      source: source,
      entryCount: entryCount,
      reason: skippedPlaceholderReason,
    );
  }
}
