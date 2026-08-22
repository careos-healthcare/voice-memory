import 'package:archiveme_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Data-governance guardrails for clinical biomarker and trajectory metrics.
///
/// Clinical signals must never leave the device via sync, backup export, or
/// product analytics. They may exist only in the on-device encrypted journal
/// partition and the clinical telemetry encrypted prefs partition.
abstract final class ClinicalDataGovernance {
  ClinicalDataGovernance._();

  static const clinicalFieldNames = {
    'biomarkers',
    'lexicalDiversity',
    'cohesionDrift',
    'emotionalVolatility',
    'clinicalTrajectory',
    'allostaticOverload',
    'wasGrounded',
    'parentHookId',
    'lexical_diversity',
    'cohesion_drift',
    'emotional_volatility',
    'previous_lexical_diversity',
    'previous_cohesion_drift',
    'previous_emotional_volatility',
    'lexical_delta',
    'drift_delta',
    'volatility_delta',
    'direction',
    'drift_type',
    'score',
  };

  /// Strips clinical fields before any outbound journal serialization.
  static JournalEntry sanitizeEntryForOutboundSync(JournalEntry entry) {
    if (entry.biomarkers == null &&
        !entry.wasGrounded &&
        entry.parentHookId == null) {
      return entry;
    }
    return entry.copyWith(
      biomarkers: null,
      wasGrounded: false,
      parentHookId: null,
    );
  }

  /// Strips clinical keys from a journal JSON map.
  static Map<String, dynamic> sanitizeJournalJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    for (final key in clinicalFieldNames) {
      copy.remove(key);
    }
    final biomarkers = copy['biomarkers'];
    if (biomarkers is Map) {
      copy.remove('biomarkers');
    }
    return copy;
  }

  /// Returns true when [meta] contains clinical metric keys — blocks analytics export.
  static bool containsClinicalMetrics(Map<String, Object?> meta) {
    for (final key in meta.keys) {
      if (clinicalFieldNames.contains(key)) return true;
    }
    return false;
  }

  /// Redacts clinical metric values from debug/analytics metadata maps.
  static Map<String, Object> redactTelemetryMeta(Map<String, Object> meta) {
    if (!containsClinicalMetrics(meta)) return meta;
    return Map<String, Object>.from(meta)
      ..removeWhere((key, _) => clinicalFieldNames.contains(key));
  }

  /// Validates biomarker scores are bounded local computation outputs.
  static bool isValidLocalBiomarkers(CognitiveBiomarkers? biomarkers) {
    if (biomarkers == null) return false;
    return _isValidScore(biomarkers.lexicalDiversity) &&
        _isValidScore(biomarkers.cohesionDrift) &&
        _isValidScore(biomarkers.emotionalVolatility);
  }

  static bool _isValidScore(double score) {
    return !score.isNaN && !score.isInfinite && score >= 0 && score <= 1;
  }
}