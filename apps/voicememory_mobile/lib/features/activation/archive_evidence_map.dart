import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_proof/visible_archive_proof_copy.dart';
import '../voice_capture/voice_capture_quality.dart';
import 'capture_context_tags.dart';
import 'context_insights.dart';

/// Stable row id for untagged usable moments.
abstract final class ArchiveEvidenceMapRowIds {
  static const untagged = 'untagged';
}

/// One context row in the evidence map.
class ArchiveEvidenceMapRow {
  const ArchiveEvidenceMapRow({
    required this.rowId,
    required this.label,
    required this.count,
  });

  final String rowId;
  final String label;
  final int count;
}

/// Local map of usable archive moments by context.
class ArchiveEvidenceMap {
  const ArchiveEvidenceMap({
    required this.showCard,
    required this.title,
    required this.subtitle,
    this.strongestContextLine,
    this.thinContextsLine,
    this.untaggedLine,
    this.nextActionLine,
    this.excludedNote,
    this.rows = const [],
    this.usableCount = 0,
  });

  final bool showCard;
  final String title;
  final String subtitle;
  final String? strongestContextLine;
  final String? thinContextsLine;
  final String? untaggedLine;
  final String? nextActionLine;
  final String? excludedNote;
  final List<ArchiveEvidenceMapRow> rows;
  final int usableCount;

  factory ArchiveEvidenceMap.hidden() => const ArchiveEvidenceMap(
        showCard: false,
        title: VisibleArchiveProofCopy.archiveEvidenceMapTitle,
        subtitle: VisibleArchiveProofCopy.archiveEvidenceMapSubtitle,
      );
}

/// Builds a deterministic evidence map from eligible journal entries.
abstract final class ArchiveEvidenceMapEngine {
  ArchiveEvidenceMapEngine._();

  static ArchiveEvidenceMap build({
    required List<JournalEntry> entries,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty) {
      return ArchiveEvidenceMap.hidden();
    }

    final taggedCounts = CaptureContextTagAnalysis.tagCounts(entries);
    final untaggedCount = _untaggedCount(eligible);
    final taggedCount =
        taggedCounts.values.fold<int>(0, (sum, count) => sum + count);
    final distinctTags = taggedCounts.length;
    final rows = _rows(taggedCounts, untaggedCount);
    final excludedCount = _excludedCount(entries, eligible);
    final excludedNote = excludedCount > 0
        ? VisibleArchiveProofCopy.archiveEvidenceMapExcludedNote
        : null;
    final thinContextsLine = _thinContextsLine(taggedCounts);
    final untaggedLine = untaggedCount > 0
        ? VisibleArchiveProofCopy.archiveEvidenceMapUntaggedCount(untaggedCount)
        : null;

    if (taggedCount == 0) {
      return ArchiveEvidenceMap(
        showCard: true,
        title: VisibleArchiveProofCopy.archiveEvidenceMapTitle,
        subtitle: VisibleArchiveProofCopy.archiveEvidenceMapSubtitle,
        untaggedLine: untaggedLine,
        nextActionLine:
            VisibleArchiveProofCopy.archiveEvidenceMapUntaggedSuggest,
        excludedNote: excludedNote,
        rows: rows,
        usableCount: eligible.length,
      );
    }

    if (taggedCount == 1) {
      return ArchiveEvidenceMap(
        showCard: true,
        title: VisibleArchiveProofCopy.archiveEvidenceMapTitle,
        subtitle: VisibleArchiveProofCopy.archiveEvidenceMapSubtitle,
        strongestContextLine:
            VisibleArchiveProofCopy.archiveEvidenceMapOneTagged,
        untaggedLine: untaggedLine,
        nextActionLine: untaggedCount > 0
            ? VisibleArchiveProofCopy.archiveEvidenceMapUntaggedSuggest
            : VisibleArchiveProofCopy.archiveEvidenceMapAddAnother,
        excludedNote: excludedNote,
        rows: rows,
        usableCount: eligible.length,
      );
    }

    if (distinctTags == 1) {
      final label = rows.firstWhere((row) => row.rowId != ArchiveEvidenceMapRowIds.untagged).label;
      return ArchiveEvidenceMap(
        showCard: true,
        title: VisibleArchiveProofCopy.archiveEvidenceMapTitle,
        subtitle: VisibleArchiveProofCopy.archiveEvidenceMapSubtitle,
        strongestContextLine:
            VisibleArchiveProofCopy.archiveEvidenceMapMostEvidenceIn(label),
        thinContextsLine: thinContextsLine,
        untaggedLine: untaggedLine,
        nextActionLine: untaggedCount > 0
            ? VisibleArchiveProofCopy.archiveEvidenceMapUntaggedSuggest
            : VisibleArchiveProofCopy.archiveEvidenceMapAddDifferentContext,
        excludedNote: excludedNote,
        rows: rows,
        usableCount: eligible.length,
      );
    }

    return ArchiveEvidenceMap(
      showCard: true,
      title: VisibleArchiveProofCopy.archiveEvidenceMapTitle,
      subtitle: VisibleArchiveProofCopy.archiveEvidenceMapSubtitle,
      strongestContextLine:
          VisibleArchiveProofCopy.archiveEvidenceMapSpansContexts,
      thinContextsLine: thinContextsLine,
      untaggedLine: untaggedLine,
      nextActionLine: _mixedNextAction(
        untaggedCount: untaggedCount,
        thinContextsLine: thinContextsLine,
      ),
      excludedNote: excludedNote,
      rows: rows,
      usableCount: eligible.length,
    );
  }

  static int _untaggedCount(List<JournalEntry> eligible) {
    var count = 0;
    for (final entry in eligible) {
      final tag = entry.captureContextTag;
      if (tag == null || tag.isEmpty) count++;
    }
    return count;
  }

  static int _excludedCount(
    List<JournalEntry> entries,
    List<JournalEntry> eligible,
  ) {
    final eligibleIds = eligible.map((entry) => entry.id).toSet();
    var count = 0;
    for (final entry in entries) {
      if (eligibleIds.contains(entry.id)) continue;
      if (entry.transcript.trim().isEmpty &&
          !VoiceCaptureQuality.isDegradedVoiceCapture(entry)) {
        continue;
      }
      count++;
    }
    return count;
  }

  static List<ArchiveEvidenceMapRow> _rows(
    Map<String, int> taggedCounts,
    int untaggedCount,
  ) {
    final rows = taggedCounts.entries
        .map(
          (entry) => ArchiveEvidenceMapRow(
            rowId: entry.key,
            label: CaptureContextTags.byId(entry.key)?.label ?? entry.key,
            count: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        return a.label.compareTo(b.label);
      });

    if (untaggedCount > 0) {
      rows.add(
        ArchiveEvidenceMapRow(
          rowId: ArchiveEvidenceMapRowIds.untagged,
          label: VisibleArchiveProofCopy.archiveEvidenceMapUntaggedRow,
          count: untaggedCount,
        ),
      );
    }
    return rows;
  }

  static String? _thinContextsLine(Map<String, int> taggedCounts) {
    if (taggedCounts.isEmpty) return null;
    final maxCount = taggedCounts.values.reduce((a, b) => a > b ? a : b);
    if (maxCount < 2) return null;

    final thinLabels = taggedCounts.entries
        .where((entry) => entry.value == 1)
        .map(
          (entry) =>
              CaptureContextTags.byId(entry.key)?.label ?? entry.key,
        )
        .toList()
      ..sort();

    if (thinLabels.isEmpty) return null;
    return VisibleArchiveProofCopy.archiveEvidenceMapThinContexts(thinLabels);
  }

  static String _mixedNextAction({
    required int untaggedCount,
    required String? thinContextsLine,
  }) {
    if (untaggedCount > 0) {
      return VisibleArchiveProofCopy.archiveEvidenceMapUntaggedSuggest;
    }
    if (thinContextsLine != null) {
      return VisibleArchiveProofCopy.archiveEvidenceMapAddDifferentContext;
    }
    return VisibleArchiveProofCopy.archiveEvidenceMapAddAnother;
  }

  static String momentCountLabel(int count) =>
      ContextInsightsEngine.momentCountLabel(count);
}
