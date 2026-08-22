import 'package:archiveme_mobile/design/empty_archive_experience.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_state_delta/archive_state_snapshot.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

enum ArchiveHealthV3 { strong, developing, uncertain }

class ArchiveStateObjectV3 {
  const ArchiveStateObjectV3({
    required this.changeSummary, required this.watchItem, required this.health, required this.hasMinimumEvidence, required this.evidenceReflectionCount, this.belief,
    this.evidenceSummary,
    this.strongestEvidenceQuote,
  });

  final String? belief;
  final String? evidenceSummary;
  final String changeSummary;
  final String watchItem;
  final ArchiveHealthV3 health;
  final bool hasMinimumEvidence;
  final int evidenceReflectionCount;
  final String? strongestEvidenceQuote;
}

String _healthLabel(ArchiveHealthV3 h) {
  switch (h) {
    case ArchiveHealthV3.strong:
      return 'Strong';
    case ArchiveHealthV3.developing:
      return 'Developing';
    case ArchiveHealthV3.uncertain:
      return 'Uncertain';
  }
}

String healthLabel(ArchiveHealthV3 h) => _healthLabel(h);

ArchiveHealthV3 _resolveHealth(int eligibleEvidenceCount) {
  if (eligibleEvidenceCount < ArchiveEvidenceGuard.minimumEvidenceCount) {
    return ArchiveHealthV3.uncertain;
  }
  if (eligibleEvidenceCount >= 8) return ArchiveHealthV3.strong;
  if (eligibleEvidenceCount >= ArchiveEvidenceGuard.minimumEvidenceCount) {
    return ArchiveHealthV3.developing;
  }
  return ArchiveHealthV3.uncertain;
}

String _watchItem({
  required int eligibleEvidenceCount,
  required bool hasChanges,
  required bool hasMinimumEvidence,
}) {
  if (!hasMinimumEvidence) {
    final need =
        ArchiveEvidenceGuard.minimumEvidenceCount - eligibleEvidenceCount;
    return need > 0
        ? 'Record $need more reflection${need == 1 ? '' : 's'} with enough spoken detail for belief and evidence surfaces.'
        : 'Add reflections with at least $archiveMinTranscriptChars characters of transcript.';
  }
  if (hasChanges) {
    return 'This belief may be changing.';
  }
  if (eligibleEvidenceCount >= ArchiveEvidenceGuard.minimumEvidenceCount) {
    return 'The archive is tracking patterns across your recorded reflections.';
  }
  return 'The archive is still gathering evidence.';
}

/// Archive Reduction v3 — belief/evidence only when reflection-backed thresholds are met.
ArchiveStateObjectV3? buildArchiveStateObjectV3({
  required List<JournalEntry> entries,
  ArchiveStateDeltaView? delta,
}) {
  if (entries.isEmpty) return null;

  final evidenceCount = archiveEvidenceReflectionCount(entries);
  final hasMin = archiveHasMinimumEvidence(entries);

  final belief = hasMin ? archiveBeliefFromReflections(entries) : null;
  final evidenceSummary = hasMin
      ? archiveWhyArchiveBelievesCopy(entries)
      : null;
  final strongest = hasMin ? archiveStrongestEvidenceQuote(entries) : null;

  final changeSummary = !hasMin
      ? EmptyArchiveCopy.needMoreEvidenceBody
      : (delta != null && delta.hasChanges
            ? delta.headline
            : 'Nothing notable has shifted since your last visit.');

  return ArchiveStateObjectV3(
    belief: belief,
    evidenceSummary: evidenceSummary,
    changeSummary: changeSummary,
    watchItem: _watchItem(
      eligibleEvidenceCount: evidenceCount,
      hasChanges: delta?.hasChanges ?? false,
      hasMinimumEvidence: hasMin,
    ),
    health: _resolveHealth(evidenceCount),
    hasMinimumEvidence: hasMin,
    evidenceReflectionCount: evidenceCount,
    strongestEvidenceQuote: strongest,
  );
}