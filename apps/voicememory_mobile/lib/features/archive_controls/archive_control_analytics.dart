import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Safe analytics for archive moment delete — metadata only.
abstract final class ArchiveControlAnalytics {
  ArchiveControlAnalytics._();

  static const deletedEvent = 'archive_moment_deleted';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void deleted({
    required String source,
    required int entryCount,
    required bool wasEvidence,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'was_evidence': wasEvidence ? 1 : 0,
    };

    captureForTest?.call(deletedEvent, props);
    ActivationFunnelAnalytics.track(
      deletedEvent,
      source: source,
      entryCount: entryCount,
      wasEvidence: wasEvidence,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_ARCHIVE_CONTROL event=$deletedEvent source=$source '
        'entry_count=$entryCount was_evidence=$wasEvidence',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
