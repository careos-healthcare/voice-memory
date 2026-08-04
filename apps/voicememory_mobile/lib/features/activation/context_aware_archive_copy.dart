import '../../models/journal_entry.dart';
import '../archive_proof/visible_archive_proof_copy.dart';
import 'capture_context_tags.dart';

/// Subtle supporting copy derived from optional capture context tags.
class ContextAwareArchiveCopy {
  const ContextAwareArchiveCopy({
    required this.showLines,
    this.summaryLine,
    this.detailLine,
  });

  final bool showLines;
  final String? summaryLine;
  final String? detailLine;

  factory ContextAwareArchiveCopy.hidden() =>
      const ContextAwareArchiveCopy(showLines: false);
}

/// Builds cautious context-aware lines for archive surfaces — not the insights card.
abstract final class ContextAwareArchiveCopyEngine {
  ContextAwareArchiveCopyEngine._();

  static const _maxNamedLabels = 2;

  static ContextAwareArchiveCopy build({required List<JournalEntry> entries}) {
    final counts = CaptureContextTagAnalysis.tagCounts(entries);
    if (counts.isEmpty) {
      return ContextAwareArchiveCopy.hidden();
    }

    final taggedCount = counts.values.fold<int>(0, (sum, count) => sum + count);
    final distinctTags = counts.length;

    if (taggedCount == 1) {
      return ContextAwareArchiveCopy(
        showLines: true,
        summaryLine: VisibleArchiveProofCopy.contextAwareStillThin,
      );
    }

    if (distinctTags == 1) {
      final tagId = counts.keys.first;
      return ContextAwareArchiveCopy(
        showLines: true,
        summaryLine: VisibleArchiveProofCopy.contextAwareMostlyAt(tagId),
        detailLine: VisibleArchiveProofCopy.contextAwareAddDifferentContext,
      );
    }

    final labels = _topFriendlyLabels(counts);
    return ContextAwareArchiveCopy(
      showLines: true,
      summaryLine: VisibleArchiveProofCopy.contextAwareAcrossContexts,
      detailLine: labels.length >= 2
          ? VisibleArchiveProofCopy.contextAwareCompareAcross(
              labels[0],
              labels[1],
            )
          : null,
    );
  }

  static List<String> _topFriendlyLabels(Map<String, int> counts) {
    final rows =
        counts.entries
            .map(
              (entry) => (
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
    return rows.take(_maxNamedLabels).map((row) => row.label).toList();
  }
}
