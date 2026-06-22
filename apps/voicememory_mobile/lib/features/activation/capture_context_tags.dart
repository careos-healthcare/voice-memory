import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_proof/visible_archive_proof_copy.dart';

/// Stable local context tag ids — never inferred, only user-selected.
abstract final class CaptureContextTagIds {
  static const work = 'work';
  static const home = 'home';
  static const family = 'family';
  static const money = 'money';
  static const health = 'health';
  static const decision = 'decision';
  static const relationship = 'relationship';
  static const other = 'other';
}

/// One optional capture context tag.
class CaptureContextTag {
  const CaptureContextTag({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

/// Fixed short tag list for optional post-save labeling.
abstract final class CaptureContextTags {
  CaptureContextTags._();

  static const all = <CaptureContextTag>[
    CaptureContextTag(
      id: CaptureContextTagIds.work,
      label: VisibleArchiveProofCopy.captureContextTagWork,
    ),
    CaptureContextTag(
      id: CaptureContextTagIds.home,
      label: VisibleArchiveProofCopy.captureContextTagHome,
    ),
    CaptureContextTag(
      id: CaptureContextTagIds.family,
      label: VisibleArchiveProofCopy.captureContextTagFamily,
    ),
    CaptureContextTag(
      id: CaptureContextTagIds.money,
      label: VisibleArchiveProofCopy.captureContextTagMoney,
    ),
    CaptureContextTag(
      id: CaptureContextTagIds.health,
      label: VisibleArchiveProofCopy.captureContextTagHealth,
    ),
    CaptureContextTag(
      id: CaptureContextTagIds.decision,
      label: VisibleArchiveProofCopy.captureContextTagDecision,
    ),
    CaptureContextTag(
      id: CaptureContextTagIds.relationship,
      label: VisibleArchiveProofCopy.captureContextTagRelationship,
    ),
    CaptureContextTag(
      id: CaptureContextTagIds.other,
      label: VisibleArchiveProofCopy.captureContextTagOther,
    ),
  ];

  static CaptureContextTag? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final tag in all) {
      if (tag.id == id) return tag;
    }
    return null;
  }

  static JournalEntry applyTag(JournalEntry entry, String tagId) =>
      entry.copyWith(captureContextTag: tagId);
}

/// Reads tag-based context diversity from eligible journal entries.
abstract final class CaptureContextTagAnalysis {
  CaptureContextTagAnalysis._();

  static List<String> taggedEligibleIds(List<JournalEntry> entries) {
    return ArchiveEvidenceGuard.eligibleEntries(entries)
        .map((entry) => entry.captureContextTag)
        .whereType<String>()
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  static bool hasAnyTaggedEligibleEntries(List<JournalEntry> entries) =>
      taggedEligibleIds(entries).isNotEmpty;

  static bool hasVariedTagContext(List<JournalEntry> entries) =>
      taggedEligibleIds(entries).toSet().length >= 2;

  static bool allTaggedSameContext(List<JournalEntry> entries) {
    final tags = taggedEligibleIds(entries);
    if (tags.length < 2) return false;
    return tags.toSet().length == 1;
  }

  static bool singleContextEvidence(List<JournalEntry> entries) {
    if (allTaggedSameContext(entries)) return true;
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 2) return false;
    if (!hasAnyTaggedEligibleEntries(entries)) return false;
    return !hasVariedTagContext(entries);
  }
}
