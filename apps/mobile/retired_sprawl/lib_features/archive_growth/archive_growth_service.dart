import 'package:archiveme_mobile/features/archive_discovery_share/archive_discovery_share_card_model.dart';
import 'package:archiveme_mobile/features/archive_discovery_share/archive_discovery_share_engine.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_growth/archive_confidence_engine.dart';
import 'package:archiveme_mobile/features/archive_growth/archive_journey_engine.dart';
import 'package:archiveme_mobile/features/archive_growth/archive_journey_store.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_builder.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/services/app_services.dart';

class ArchiveGrowthSnapshot {
  const ArchiveGrowthSnapshot({
    required this.confidence,
    required this.journey,
    required this.shareDiscoveries,
    this.archiveV1,
  });

  final ArchiveConfidenceView confidence;
  final ArchiveJourneyView journey;
  final List<ArchiveDiscoveryShareCardModel> shareDiscoveries;
  final ArchiveV1View? archiveV1;
}

/// Loads growth-loop views from journal + existing V1 engines.
class ArchiveGrowthService {
  ArchiveGrowthService({required this._journeyStore});

  final ArchiveJourneyStore _journeyStore;

  static Future<ArchiveGrowthSnapshot> load() async {
    final s = AppServices.instance;
    final entries = await s.journal.loadAll();
    ArchiveV1View? v1;
    if (archiveHasMinimumEvidence(entries)) {
      v1 = await const ArchiveV1Builder().build(
        entries: entries,
        evolutionService: s.beliefEvolution,
      );
    }
    final completed = await ArchiveJourneyStore(s.prefs).readCompleted();
    return ArchiveGrowthSnapshot(
      confidence: ArchiveConfidenceEngine.build(
        entries: entries,
        archiveV1: v1,
      ),
      journey: ArchiveJourneyEngine.build(
        entries: entries,
        archiveV1: v1,
        markedComplete: completed,
      ),
      shareDiscoveries: ArchiveDiscoveryShareEngine.build(
        entries: entries,
        archiveV1: v1,
      ),
      archiveV1: v1,
    );
  }

  Future<void> markJourneyStep(ArchiveJourneyStepId id) =>
      _journeyStore.markComplete(id);
}