import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_proof/visible_archive_proof_copy.dart';
import 'capture_context_tags.dart';

/// Distribution row for one tagged context.
class ContextInsightRow {
  const ContextInsightRow({
    required this.tagId,
    required this.label,
    required this.count,
  });

  final String tagId;
  final String label;
  final int count;
}

/// Local readout of where tagged moments show up.
class ContextInsights {
  const ContextInsights({
    required this.showCard,
    required this.title,
    required this.subtitle,
    required this.summaryLine,
    this.detailLine,
    this.cautionLine,
    this.topContexts = const [],
  });

  final bool showCard;
  final String title;
  final String subtitle;
  final String summaryLine;
  final String? detailLine;
  final String? cautionLine;
  final List<ContextInsightRow> topContexts;

  factory ContextInsights.hidden() => const ContextInsights(
        showCard: false,
        title: VisibleArchiveProofCopy.contextInsightsTitle,
        subtitle: VisibleArchiveProofCopy.contextInsightsSubtitle,
        summaryLine: '',
      );
}

/// Builds deterministic context insight from tagged eligible moments.
abstract final class ContextInsightsEngine {
  ContextInsightsEngine._();

  static const _maxTopContexts = 3;
  static const _sparseTaggedCount = 2;

  static ContextInsights build({
    required List<JournalEntry> entries,
  }) {
    final counts = _tagCounts(entries);
    if (counts.isEmpty) {
      return ContextInsights.hidden();
    }

    final taggedCount = counts.values.fold<int>(0, (sum, count) => sum + count);
    final distinctTags = counts.length;
    final topContexts = _topContexts(counts);
    final cautionLine = taggedCount <= _sparseTaggedCount
        ? VisibleArchiveProofCopy.contextInsightsStillThin
        : null;

    if (taggedCount == 1) {
      return ContextInsights(
        showCard: true,
        title: VisibleArchiveProofCopy.contextInsightsTitle,
        subtitle: VisibleArchiveProofCopy.contextInsightsSubtitle,
        summaryLine: VisibleArchiveProofCopy.contextInsightsOneTagged,
        detailLine: VisibleArchiveProofCopy.contextInsightsAddAnotherTagged,
      );
    }

    if (distinctTags == 1) {
      final label = topContexts.first.label;
      return ContextInsights(
        showCard: true,
        title: VisibleArchiveProofCopy.contextInsightsTitle,
        subtitle: VisibleArchiveProofCopy.contextInsightsSubtitle,
        summaryLine: VisibleArchiveProofCopy.contextInsightsMostlyIn(label),
        detailLine: VisibleArchiveProofCopy.contextInsightsAddDifferentContext,
        cautionLine: cautionLine,
        topContexts: topContexts,
      );
    }

    return ContextInsights(
      showCard: true,
      title: VisibleArchiveProofCopy.contextInsightsTitle,
      subtitle: VisibleArchiveProofCopy.contextInsightsSubtitle,
      summaryLine: VisibleArchiveProofCopy.contextInsightsAcrossContexts,
      detailLine: null,
      cautionLine: cautionLine,
      topContexts: topContexts.take(_maxTopContexts).toList(),
    );
  }

  static Map<String, int> _tagCounts(List<JournalEntry> entries) {
    final counts = <String, int>{};
    for (final entry in ArchiveEvidenceGuard.eligibleEntries(entries)) {
      final tagId = entry.captureContextTag;
      if (tagId == null || tagId.isEmpty) continue;
      counts[tagId] = (counts[tagId] ?? 0) + 1;
    }
    return counts;
  }

  static List<ContextInsightRow> _topContexts(Map<String, int> counts) {
    final rows = counts.entries
        .map(
          (entry) => ContextInsightRow(
            tagId: entry.key,
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
    return rows.take(_maxTopContexts).toList();
  }

  static String momentCountLabel(int count) =>
      count == 1 ? '1 moment' : '$count moments';
}
