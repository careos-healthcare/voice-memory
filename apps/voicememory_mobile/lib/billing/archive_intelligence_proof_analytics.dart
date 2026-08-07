import '../services/product_analytics.dart';

abstract class ArchiveIntelligenceProofAnalytics {
  ArchiveIntelligenceProofAnalytics._();

  static Future<void> paywallProofSeen({
    required String surface,
    required bool usedFallback,
    int? themeCount,
    int? theoryCount,
    int? changeCount,
  }) {
    return ProductAnalytics.track(
      'paywall_proof_seen',
      parameters: {
        'surface': surface,
        'used_fallback': usedFallback ? 1 : 0,
        'theme_count': ?themeCount,
        'theory_count': ?theoryCount,
        'change_count': ?changeCount,
      },
    );
  }
}
