import 'package:archiveme_mobile/design/empty_archive_experience.dart';
import 'package:archiveme_mobile/features/archive_beliefs/belief_change_timeline.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/evidence_contract/evidence_eligibility_policy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Typed eligibility for the Archive "Changes" subsection — evidence contract only.
abstract final class ArchiveChangesEligibility {
  ArchiveChangesEligibility._();

  static bool isEligible({
    required List<JournalEntry> entries,
    required List<BeliefChangeTimelineItem> timeline,
  }) {
    if (isIntentionalEmptyArchive(entries)) return false;
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final outcome = EvidenceEligibilityPolicy.evaluateChangesSurface(
      admittedMomentCount: eligible.length,
      hasEligibleTimelineItems: timeline.isNotEmpty,
    );
    return outcome == EvidenceEligibilityOutcome.allowed;
  }
}
