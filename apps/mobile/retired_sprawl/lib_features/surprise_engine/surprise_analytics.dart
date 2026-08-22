import 'package:archiveme_mobile/features/surprise_engine/surprise_models.dart';
import 'package:archiveme_mobile/services/product_analytics.dart';

/// Surprise Pipeline V1 analytics.
class SurpriseAnalytics {
  SurpriseAnalytics._();

  static Future<void> opened(ArchiveSurprise surprise) async {
    await ProductAnalytics.trackStrings('surprise_opened', {
      'type': surprise.type.name,
      'id': surprise.id,
      'evidence_count': surprise.evidenceIds.length.toString(),
    });
  }

  static Future<void> ignored(ArchiveSurprise surprise) async {
    await ProductAnalytics.trackStrings('surprise_ignored', {
      'type': surprise.type.name,
      'id': surprise.id,
    });
  }

  static Future<void> shared(ArchiveSurprise surprise) async {
    await ProductAnalytics.trackStrings('surprise_shared', {
      'type': surprise.type.name,
      'id': surprise.id,
    });
  }

  static Future<void> surfaced(ArchiveSurprise surprise) async {
    await ProductAnalytics.trackStrings('surprise_surfaced', {
      'type': surprise.type.name,
      'id': surprise.id,
    });
  }
}