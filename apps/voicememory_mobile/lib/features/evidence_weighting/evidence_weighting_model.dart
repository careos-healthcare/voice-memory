import '../correction_memory/correction_memory_model.dart';

/// Lightweight evidence freshness weight — not a proof verdict.
enum EvidenceWeightState {
  fresh,
  repeated,
  fading,
  softened,
  oldSignal,
  needsFreshProof,
}

extension EvidenceWeightStateAnalytics on EvidenceWeightState {
  String get analyticsValue => switch (this) {
        EvidenceWeightState.fresh => 'fresh',
        EvidenceWeightState.repeated => 'repeated',
        EvidenceWeightState.fading => 'fading',
        EvidenceWeightState.softened => 'softened',
        EvidenceWeightState.oldSignal => 'old_signal',
        EvidenceWeightState.needsFreshProof => 'needs_fresh_proof',
      };
}

/// Resolved weighting summary from existing eligible entries only.
class EvidenceWeightingResult {
  const EvidenceWeightingResult({
    required this.entryCount,
    required this.hasConfirmedRepeat,
    required this.hasRecentEntry,
    required this.hasOlderEntry,
    required this.hasSofteningSignal,
    required this.hasQuietSignal,
    required this.primaryState,
    required this.secondaryStates,
    required this.shouldShow,
    this.correctionMemory,
  });

  final int entryCount;
  final bool hasConfirmedRepeat;
  final bool hasRecentEntry;
  final bool hasOlderEntry;
  final bool hasSofteningSignal;
  final bool hasQuietSignal;
  final EvidenceWeightState primaryState;
  final List<EvidenceWeightState> secondaryStates;
  final bool shouldShow;
  final CorrectionMemorySnapshot? correctionMemory;

  List<EvidenceWeightState> get displayStates => [
        primaryState,
        ...secondaryStates.where((state) => state != primaryState),
      ];
}
