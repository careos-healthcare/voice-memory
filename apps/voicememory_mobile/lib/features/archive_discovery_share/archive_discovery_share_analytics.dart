import '../../services/product_analytics.dart';
import '../first25/first25_user_metrics.dart';
import 'archive_discovery_share_types.dart';

/// Archive Discovery Share Cards V2 — share events.
abstract final class ArchiveDiscoveryShareAnalytics {
  ArchiveDiscoveryShareAnalytics._();

  static Future<void> discoveryShareTapped({
    required ArchiveDiscoveryShareCardType cardType,
    required String cardId,
    required String surface,
  }) {
    return ProductAnalytics.trackStrings(
      'discovery_share_tapped',
      {
        'card_type': cardType.analyticsValue,
        'card_id': cardId,
        'surface': surface,
      },
    );
  }

  static Future<void> discoveryShared({
    required ArchiveDiscoveryShareCardType cardType,
    required String cardId,
    required String surface,
    required String exportMethod,
    int? evidenceRecordingCount,
  }) async {
    await ProductAnalytics.trackStrings(
      'discovery_shared',
      {
        'card_type': cardType.analyticsValue,
        'card_id': cardId,
        'surface': surface,
        'export_method': exportMethod,
        if (evidenceRecordingCount != null)
          'evidence_recording_count': '$evidenceRecordingCount',
      },
    );
    await First25UserMetrics.trackShareCardShared(
      surface: surface,
      cardType: cardType.analyticsValue,
      exportMethod: exportMethod,
    );
  }
}
