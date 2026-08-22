import 'package:archiveme_mobile/features/archive_evolution/archive_evolution_models.dart';
import 'package:archiveme_mobile/services/product_analytics.dart';

class ArchiveEvolutionAnalytics {
  ArchiveEvolutionAnalytics._();

  static Future<void> seen(ArchiveEvolution evolution) async {
    await ProductAnalytics.trackStrings('archive_evolution_seen', {
      'kind': evolution.kind.name,
      'id': evolution.id,
      'confidence': evolution.confidence.toString(),
    });
  }

  static Future<void> opened(ArchiveEvolution evolution) async {
    await ProductAnalytics.trackStrings('archive_evolution_opened', {
      'kind': evolution.kind.name,
      'id': evolution.id,
    });
  }

  static Future<void> ignored(ArchiveEvolution evolution) async {
    await ProductAnalytics.trackStrings('archive_evolution_ignored', {
      'kind': evolution.kind.name,
      'id': evolution.id,
    });
  }

  static Future<void> completed(ArchiveEvolution evolution) async {
    await ProductAnalytics.trackStrings('archive_evolution_completed', {
      'kind': evolution.kind.name,
      'id': evolution.id,
    });
  }
}