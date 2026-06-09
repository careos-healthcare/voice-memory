import '../services/product_analytics.dart';

abstract final class ArchiveIntelligenceProofAnalytics {
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
        if (themeCount != null) 'theme_count': themeCount,
        if (theoryCount != null) 'theory_count': theoryCount,
        if (changeCount != null) 'change_count': changeCount,
      },
    );
  }
}
