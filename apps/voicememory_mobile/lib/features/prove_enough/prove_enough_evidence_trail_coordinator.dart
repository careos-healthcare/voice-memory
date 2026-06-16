import '../loop_mode/loop_mode_coordinator.dart';
import 'next_evidence_mission_store.dart';
import 'prove_enough_contradiction_store.dart';
import 'prove_enough_evidence_trail_engine.dart';
import 'prove_enough_evidence_trail_model.dart';
import '../signal_journey/signal_journey_coordinator.dart';
import '../signal_review/signal_review_coordinator.dart';
import '../../services/app_services.dart';

/// Loads journal + journey data for the prove_enough evidence trail screen.
abstract class ProveEnoughEvidenceTrailCoordinator {
  ProveEnoughEvidenceTrailCoordinator._();

  static const _engine = ProveEnoughEvidenceTrailEngine();

  static Future<ProveEnoughEvidenceTrail> load() async {
    if (!AppServices.isInitialized) {
      return const ProveEnoughEvidenceTrail(
        supportingMoments: [],
        contradictionMoments: [],
        restGuiltMoments: [],
        choiceMoments: [],
        triggerSummary: '',
        whatChanged: '',
      );
    }

    final entries = await AppServices.instance.journalStore.loadAll();
    final journey = await SignalJourneyCoordinator.loadActive();
    final review = await SignalReviewCoordinator.loadForActiveJourney();
    final contradictions = journey == null
        ? await ProveEnoughContradictionStore.instance().loadAll()
        : await ProveEnoughContradictionStore.instance().loadForJourney(
            journey.id,
          );
    final mission = await NextEvidenceMissionStore.instance().load();
    final loop = await LoopModeCoordinator.loadActive();

    if (loop?.isProveEnough != true) {
      return _engine.build(entries: entries);
    }

    return _engine.build(
      entries: entries,
      journey: journey,
      review: review,
      contradictions: contradictions,
      latestMission: mission,
    );
  }
}
