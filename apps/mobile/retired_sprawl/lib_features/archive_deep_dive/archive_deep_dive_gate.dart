import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';

/// When Archive Deep Dive may be opened from the belief hero or routes.
abstract class ArchiveDeepDiveGate {
  ArchiveDeepDiveGate._();

  static bool canOpenDeepDive(ArchiveV1View view) {
    if (!view.hasMinimumEvidence) return false;
    final belief = view.belief;
    if (belief == null) return false;
    if (belief.statement.trim().isEmpty) return false;
    if (belief.evidenceCount < archiveMinEvidenceReflections) return false;
    if (belief.supportingEntries.isEmpty && view.eligibleEntries.isEmpty) {
      return false;
    }
    return true;
  }
}