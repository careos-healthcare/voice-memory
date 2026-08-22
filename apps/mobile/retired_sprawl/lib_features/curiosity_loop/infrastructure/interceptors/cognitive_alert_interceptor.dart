import 'package:archiveme_mobile/features/curiosity_loop/services/clinical_cognitive_telemetry.dart';
import 'package:archiveme_mobile/features/journal/domain/interceptors/journal_save_interceptor.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

typedef ClinicalDriftWarningHandler =
    void Function(ClinicalDriftWarning warning);

/// Local warning payload for high clinical drift biomarkers.
class ClinicalDriftWarning {
  const ClinicalDriftWarning({
    required this.entryId,
    required this.driftType,
    required this.score,
  });

  final String entryId;
  final String driftType;
  final double score;
}

/// Emits clinical drift telemetry when passive biomarkers exceed thresholds.
class CognitiveAlertInterceptor implements JournalSaveInterceptor {
  CognitiveAlertInterceptor({
    ClinicalCognitiveTelemetry? telemetry,
    this._onWarning,
    this._threshold = 0.8,
  }) : _telemetry = telemetry ?? const ClinicalCognitiveTelemetry();

  static const emotionalVolatilityDriftType = 'emotional_volatility';
  static const cohesionDriftType = 'cohesion_drift';

  final ClinicalCognitiveTelemetry _telemetry;
  final ClinicalDriftWarningHandler? _onWarning;
  final double _threshold;

  @override
  Future<void> onEntrySaved(JournalEntry entry) async {
    final biomarkers = entry.biomarkers;
    if (biomarkers == null) return;

    if (biomarkers.emotionalVolatility > _threshold) {
      _dispatchWarning(
        entryId: entry.id,
        driftType: emotionalVolatilityDriftType,
        score: biomarkers.emotionalVolatility,
      );
    }

    if (biomarkers.cohesionDrift > _threshold) {
      _dispatchWarning(
        entryId: entry.id,
        driftType: cohesionDriftType,
        score: biomarkers.cohesionDrift,
      );
    }
  }

  void _dispatchWarning({
    required String entryId,
    required String driftType,
    required double score,
  }) {
    _telemetry.trackClinicalDriftDetected(
      entryId: entryId,
      driftType: driftType,
      score: score,
    );
    _onWarning?.call(
      ClinicalDriftWarning(
        entryId: entryId,
        driftType: driftType,
        score: score,
      ),
    );
  }
}