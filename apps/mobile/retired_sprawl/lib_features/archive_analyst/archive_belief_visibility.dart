import 'package:archiveme_mobile/features/archive_theory/archive_theory_models.dart';

/// Minimum thresholds for beliefs shown in Archive UI.
abstract class ArchiveBeliefVisibility {
  ArchiveBeliefVisibility._();

  static const int minConfidencePercent = 15;
  static const int minEvidenceCount = 3;

  /// Whether a belief row should appear in Analyst / Competing / Emerging / Fading.
  static bool isVisibleBelief({
    required String statement,
    required int confidencePercent,
    required int evidenceCount,
  }) {
    if (isTraitOrPlaceholder(statement)) return false;
    if (confidencePercent < minConfidencePercent) return false;
    if (evidenceCount < minEvidenceCount) return false;
    return true;
  }

  /// Whether the archive theory hero should render.
  static bool isVisibleTheory(ArchiveCurrentTheory theory) {
    return isVisibleBelief(
      statement: theory.statement,
      confidencePercent: theory.confidencePercent,
      evidenceCount: theory.evidenceCount,
    );
  }

  static bool isTraitOrPlaceholder(String statement) {
    final lower = statement.trim().toLowerCase();
    if (lower.length < 12) return true;
    if (lower.contains('still gathering evidence') ||
        lower.contains('working belief is forming')) {
      return true;
    }
    return isTraitTemplate(lower);
  }

  static bool isTraitTemplate(String lower) {
    return lower.startsWith('you focus on') ||
        lower.startsWith('you tend to') ||
        lower.startsWith('you often') ||
        lower.startsWith('you prioritize') ||
        lower.startsWith('you express confidence') ||
        lower.startsWith('you avoid conflict') ||
        lower.startsWith('your archive working belief');
  }
}