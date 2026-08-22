import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:archiveme_mobile/features/post_save_insight/selected_signal_coordinator.dart';
import 'package:archiveme_mobile/features/post_save_insight/signal_feedback_store.dart';
import 'package:archiveme_mobile/features/retention/pattern_hypothesis_engine.dart';
import 'package:archiveme_mobile/features/retention/pattern_hypothesis_model.dart';
import 'package:archiveme_mobile/features/signal_archive/signal_archive_snapshot.dart';
import 'package:archiveme_mobile/features/signal_archive/signal_corrections_engine.dart';
import 'package:archiveme_mobile/features/signal_archive/signal_corrections_model.dart';
import 'package:archiveme_mobile/features/signal_archive/signal_evidence_engine.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Loads journal-backed archive signal state for detail, trail, and dashboard surfaces.
abstract class SignalArchiveCoordinator {
  SignalArchiveCoordinator._();

  static Future<SignalArchiveSnapshot> load() async {
    if (!AppServices.isInitialized) {
      return SignalArchiveSnapshot(
        selectedSignal: null,
        evidenceTrail: const SignalEvidenceEngine().build(
          signal: null,
          entries: const [],
        ),
        corrections: const SignalCorrectionView(
          rejectedTitles: [],
          selectedAlternativeTitle: null,
          hasCorrections: false,
        ),
        hypothesis: null,
        reflectionCount: 0,
      );
    }

    final entries = await AppServices.instance.journalStore.loadAll();
    final selected = await SelectedSignalCoordinator.loadCurrent();
    final feedback = await SignalFeedbackStore.instance().loadAll();

    PatternHypothesis? hypothesis;
    if (ArchiveEvidenceQualityGate.allowsPatternHypothesis(entries)) {
      hypothesis = await const PatternHypothesisEngine().build(entries);
      if (!hypothesis.hasEnoughData) hypothesis = null;
    }

    final trail = const SignalEvidenceEngine().build(
      signal: selected,
      entries: entries,
    );
    final corrections = const SignalCorrectionsEngine().build(
      feedback: feedback,
      currentSignal: selected,
    );

    return SignalArchiveSnapshot(
      selectedSignal: selected,
      evidenceTrail: trail,
      corrections: corrections,
      hypothesis: hypothesis,
      reflectionCount: entries.length,
    );
  }
}