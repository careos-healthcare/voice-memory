import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'evidence_anchor_model.dart';

/// Metadata-only analytics for evidence anchor extraction.
abstract final class EvidenceAnchorAnalytics {
  EvidenceAnchorAnalytics._();

  static const seenEvent = 'evidence_anchor_extraction_seen';
  static const emptyEvent = 'evidence_anchor_extraction_empty';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void trackExtraction({
    required EvidenceAnchorExtractionResult result,
  }) {
    if (!result.shouldExtract) return;

    if (result.hasSafeAnchor) {
      seen(
        source: result.source,
        entryCount: result.entryCount,
        anchorCount: result.anchors.length,
        anchorTypes: result.anchorTypeAnalyticsValues,
        hasRecentAnchor: result.hasRecentAnchor,
        hasCorrectionAnchor: result.hasCorrectionAnchor,
        hasChangeAnchor: result.hasChangeAnchor,
      );
      return;
    }

    empty(source: result.source, entryCount: result.entryCount);
  }

  static void seen({
    required String source,
    required int entryCount,
    required int anchorCount,
    required List<String> anchorTypes,
    required bool hasRecentAnchor,
    required bool hasCorrectionAnchor,
    required bool hasChangeAnchor,
  }) {
    final props = <String, Object>{
      'entry_count': entryCount,
      'source': source,
      'anchor_count': anchorCount,
      'anchor_types': anchorTypes.join(','),
      'has_recent_anchor': hasRecentAnchor ? 1 : 0,
      'has_correction_anchor': hasCorrectionAnchor ? 1 : 0,
      'has_change_anchor': hasChangeAnchor ? 1 : 0,
    };
    captureForTest?.call(seenEvent, props);
    ActivationFunnelAnalytics.track(
      seenEvent,
      source: source,
      entryCount: entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_EVIDENCE_ANCHOR event=$seenEvent source=$source '
        'entry_count=$entryCount anchor_count=$anchorCount '
        'anchor_types=${anchorTypes.join(",")} '
        'has_recent_anchor=$hasRecentAnchor has_correction_anchor=$hasCorrectionAnchor '
        'has_change_anchor=$hasChangeAnchor',
      );
    }
  }

  static void empty({required String source, required int entryCount}) {
    final props = <String, Object>{
      'entry_count': entryCount,
      'source': source,
      'anchor_count': 0,
      'anchor_types': '',
      'has_recent_anchor': 0,
      'has_correction_anchor': 0,
      'has_change_anchor': 0,
    };
    captureForTest?.call(emptyEvent, props);
    ActivationFunnelAnalytics.track(
      emptyEvent,
      source: source,
      entryCount: entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_EVIDENCE_ANCHOR event=$emptyEvent source=$source '
        'entry_count=$entryCount',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
