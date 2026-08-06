import '../../../../models/journal_entry.dart';
import '../../../journal/domain/interceptors/journal_save_interceptor.dart';
import '../../domain/models/cognitive_biomarkers.dart';
import '../../domain/services/moving_baseline_calculator.dart';
import '../../repositories/cognitive_baseline_store.dart';
import '../../services/cognitive_baseline_telemetry.dart';

typedef CognitiveBaselineUpdateHandler =
    void Function(CognitiveBaselineUpdateRecord record);

/// Maintains a persisted EWMA macro baseline after verified biomarker saves.
class CognitiveBaselineInterceptor implements JournalSaveInterceptor {
  CognitiveBaselineInterceptor({
    this._baselineStore,
    MovingBaselineCalculator? calculator,
    CognitiveBaselineTelemetry? telemetry,
    this._onBaselineUpdated,
    DateTime Function()? clock,
  }) : _calculator = calculator ?? const MovingBaselineCalculator(),
       _telemetry = telemetry ?? const CognitiveBaselineTelemetry(),
       _clock = clock ?? DateTime.now;

  final CognitiveBaselineStore? _baselineStore;
  final MovingBaselineCalculator _calculator;
  final CognitiveBaselineTelemetry _telemetry;
  final CognitiveBaselineUpdateHandler? _onBaselineUpdated;
  final DateTime Function() _clock;

  CognitiveBaselineStore get _resolvedBaselineStore =>
      _baselineStore ?? LocalCognitiveBaselineStore.instance();

  @override
  Future<void> onEntrySaved(JournalEntry entry) async {
    final observation = entry.biomarkers;
    if (observation == null || !_hasValidBiomarkers(observation)) return;
    if (entry.id.trim().isEmpty) return;

    final previousSnapshot = await _resolvedBaselineStore.loadSnapshot();
    final previousBaseline = previousSnapshot?.baseline;
    final updatedBaseline = previousBaseline == null
        ? observation
        : _calculator.updateBaseline(previousBaseline, observation);

    final snapshot = CognitiveBaselineSnapshot(
      baseline: updatedBaseline,
      lastEntryId: entry.id,
      updatedAt: _clock().toUtc(),
      observationCount: (previousSnapshot?.observationCount ?? 0) + 1,
    );

    await _resolvedBaselineStore.saveSnapshot(snapshot);
    _telemetry.trackBaselineUpdated(
      entryId: entry.id,
      updatedBaseline: updatedBaseline,
      observationCount: snapshot.observationCount,
      previousBaseline: previousBaseline,
    );
    _onBaselineUpdated?.call(
      CognitiveBaselineUpdateRecord(
        entryId: entry.id,
        observation: observation,
        previousBaseline: previousBaseline,
        updatedBaseline: updatedBaseline,
        observationCount: snapshot.observationCount,
      ),
    );
  }

  static bool _hasValidBiomarkers(CognitiveBiomarkers biomarkers) {
    return _isValidScore(biomarkers.lexicalDiversity) &&
        _isValidScore(biomarkers.cohesionDrift) &&
        _isValidScore(biomarkers.emotionalVolatility);
  }

  static bool _isValidScore(double score) {
    return !score.isNaN && !score.isInfinite && score >= 0 && score <= 1;
  }
}
