import '../post_save_insight/selected_signal_model.dart';
import '../retention/pattern_hypothesis_model.dart';
import 'signal_corrections_model.dart';
import 'signal_evidence_model.dart';

/// Loaded state for archive signal surfaces.
class SignalArchiveSnapshot {
  const SignalArchiveSnapshot({
    required this.selectedSignal,
    required this.evidenceTrail,
    required this.corrections,
    required this.hypothesis,
    required this.reflectionCount,
  });

  final SelectedSignalRecord? selectedSignal;
  final SignalEvidenceTrail evidenceTrail;
  final SignalCorrectionView corrections;
  final PatternHypothesis? hypothesis;
  final int reflectionCount;

  bool get hasActiveSignal => selectedSignal != null;

  int get evidenceCount => evidenceTrail.items.length;
}
