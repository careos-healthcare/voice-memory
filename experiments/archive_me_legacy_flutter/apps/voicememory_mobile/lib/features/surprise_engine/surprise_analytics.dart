import '../../services/product_analytics.dart';
import 'surprise_models.dart';

/// Surprise Pipeline V1 analytics.
class SurpriseAnalytics {
  SurpriseAnalytics._();

  static Future<void> opened(ArchiveSurprise surprise) async {
    await ProductAnalytics.track(
      'surprise_opened',
      parameters: {
        'type': surprise.type.name,
        'evidence_count': surprise.evidenceIds.length,
      },
    );
  }

  static Future<void> ignored(ArchiveSurprise surprise) async {
    await ProductAnalytics.trackStrings('surprise_ignored', {
      'type': surprise.type.name,
    });
  }

  static Future<void> shared(ArchiveSurprise surprise) async {
    await ProductAnalytics.trackStrings('surprise_shared', {
      'type': surprise.type.name,
    });
  }

  static Future<void> surfaced(ArchiveSurprise surprise) async {
    await ProductAnalytics.trackStrings('surprise_surfaced', {
      'type': surprise.type.name,
    });
  }
}
