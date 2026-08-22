import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/evidence_locker_compact.dart' show EvidenceLockerCompact;

export 'archive_evidence_guard.dart';
export 'archive_evidence_quality.dart';
export 'archive_evidence_quality_gate.dart';
export 'archive_evidence_threshold.dart';

/// Minimum reflections with usable transcript before belief/evidence surfaces render.
int get archiveMinEvidenceReflections =>
    ArchiveEvidenceGuard.minimumEvidenceCount;

/// Matches [EvidenceLockerCompact] — transcripts shorter than this are not evidence.
int get archiveMinTranscriptChars =>
    ArchiveEvidenceGuard.minimumTranscriptChars;

List<JournalEntry> archiveEligibleEvidenceEntries(List<JournalEntry> entries) =>
    ArchiveEvidenceGuard.eligibleEntries(entries);

int archiveEvidenceReflectionCount(List<JournalEntry> entries) =>
    ArchiveEvidenceGuard.eligibleReflectionCount(entries);

bool archiveHasMinimumEvidence(List<JournalEntry> entries) =>
    ArchiveEvidenceGuard.hasMinimumEvidence(entries);

/// Strongest line = most recent eligible transcript (real user words).
String? archiveStrongestEvidenceQuote(List<JournalEntry> entries) {
  final eligible = archiveEligibleEvidenceEntries(entries);
  if (eligible.isEmpty) return null;
  final t = eligible.last.transcript.trim();
  if (t.length <= 120) return t;
  return '${t.substring(0, 120)}…';
}

/// Working belief from reflections — observation first, else recent transcript.
String? archiveBeliefFromReflections(List<JournalEntry> entries) {
  if (!ArchiveEvidenceGuard.canSurfaceBelief(entries)) return null;

  final eligible = archiveEligibleEvidenceEntries(entries);
  if (eligible.isEmpty) return null;

  for (final e in eligible.reversed) {
    final obs = e.reflection.concreteObservation.trim();
    if (obs.length >= 16) return obs;
  }
  return archiveStrongestEvidenceQuote(entries);
}

String? archiveWhyArchiveBelievesCopy(List<JournalEntry> entries) {
  if (!ArchiveEvidenceGuard.canSurfaceBelief(entries)) return null;

  final eligible = archiveEligibleEvidenceEntries(entries);
  if (eligible.isEmpty) return null;

  final quote = archiveStrongestEvidenceQuote(entries);
  if (quote == null) return null;

  return 'The archive is weighing ${eligible.length} reflections with usable '
      'transcripts. Strongest recent line: “$quote”';
}