import '../features/explainable_conclusion/explainable_conclusion.dart';
import 'evidence_receipt_analytics.dart';

enum FocusedReturnSurface { postSave, changes }

enum FocusedReturnConclusionKind {
  observation,
  possibleRepeat,
  possibleChange,
  supportedPattern,
}

/// Typed, content-free analytics for the focused V1 return experience.
///
/// This facade accepts only enums and counts. Transcripts, quotes, statements,
/// correction notes, entry identifiers, and dates cannot cross this boundary.
abstract final class FocusedReturnAnalytics {
  FocusedReturnAnalytics._();

  static Future<void> conclusionShown({
    required FocusedReturnConclusionKind kind,
    required int evidenceCount,
    required EvidenceConfidenceBand confidenceBand,
    required FocusedReturnSurface surface,
  }) => EvidenceReceiptAnalytics.auditableConclusionShown(
    kind: kind._token,
    evidenceCount: evidenceCount,
    confidenceBand: confidenceBand.name,
    origin: surface._token,
  );

  static Future<void> earlyComparisonShown({
    required int evidenceCount,
    required EvidenceConfidenceBand confidenceBand,
    required FocusedReturnSurface surface,
  }) => EvidenceReceiptAnalytics.earlyComparisonShown(
    evidenceCount: evidenceCount,
    confidenceBand: confidenceBand.name,
    origin: surface._token,
  );

  static Future<void> noConclusionShown(FocusedReturnSurface surface) =>
      surface == FocusedReturnSurface.postSave
      ? EvidenceReceiptAnalytics.postSaveNoConclusion()
      : EvidenceReceiptAnalytics.lowEvidenceSuppressed(origin: surface._token);

  static Future<void> changesViewed({required bool hasReliableChange}) =>
      EvidenceReceiptAnalytics.changesViewed(
        hasReliableChange: hasReliableChange,
      );
}

extension on FocusedReturnSurface {
  String get _token => switch (this) {
    FocusedReturnSurface.postSave => 'post_save',
    FocusedReturnSurface.changes => 'changes',
  };
}

extension on FocusedReturnConclusionKind {
  String get _token => switch (this) {
    FocusedReturnConclusionKind.observation => 'observation',
    FocusedReturnConclusionKind.possibleRepeat => 'pattern',
    FocusedReturnConclusionKind.possibleChange => 'change',
    FocusedReturnConclusionKind.supportedPattern => 'pattern',
  };
}
