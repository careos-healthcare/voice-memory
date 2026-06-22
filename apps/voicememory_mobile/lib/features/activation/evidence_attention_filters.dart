import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_proof/visible_archive_proof_copy.dart';
import 'archive_evidence_map.dart';
import 'archive_insight_feedback.dart';
import 'capture_context_tags.dart';
import 'insight_quality_dashboard.dart';

/// Which attention filter chip the user tapped.
enum EvidenceAttentionFilterKind {
  untagged,
  thinContexts,
  sameContext,
  corrections,
  hidden,
}

/// Where a filter chip should navigate.
enum EvidenceAttentionFilterDestination {
  untaggedDrilldown,
  thinContextDrilldown,
  archiveBelief,
  insightQuality,
}

/// One local attention filter chip.
class EvidenceAttentionFilter {
  const EvidenceAttentionFilter({
    required this.kind,
    required this.label,
    required this.destination,
    this.contextTagId,
  });

  final EvidenceAttentionFilterKind kind;
  final String label;
  final EvidenceAttentionFilterDestination destination;
  final String? contextTagId;

  String? resolveRoute() {
    switch (destination) {
      case EvidenceAttentionFilterDestination.untaggedDrilldown:
        return ArchiveEvidenceMapNavigation.contextPath(
          ArchiveEvidenceMapRowIds.untagged,
        );
      case EvidenceAttentionFilterDestination.thinContextDrilldown:
        final tagId = contextTagId;
        if (tagId == null || tagId.isEmpty) return null;
        return ArchiveEvidenceMapNavigation.contextPath(tagId);
      case EvidenceAttentionFilterDestination.archiveBelief:
        return '/archive-belief';
      case EvidenceAttentionFilterDestination.insightQuality:
        return InsightQualityNavigation.route;
    }
  }
}

/// Compact “Needs attention” chips for archive evidence.
class EvidenceAttentionFilters {
  const EvidenceAttentionFilters({
    required this.showCard,
    required this.title,
    this.filters = const [],
  });

  final bool showCard;
  final String title;
  final List<EvidenceAttentionFilter> filters;

  factory EvidenceAttentionFilters.hidden() => const EvidenceAttentionFilters(
        showCard: false,
        title: VisibleArchiveProofCopy.evidenceAttentionFiltersTitle,
      );
}

/// Builds local-only attention filters from eligible evidence and feedback.
abstract final class EvidenceAttentionFiltersEngine {
  EvidenceAttentionFiltersEngine._();

  static EvidenceAttentionFilters build({
    required List<JournalEntry> entries,
    Set<EvidenceAttentionFilterKind> omitKinds = const {},
  }) {
    final filters = <EvidenceAttentionFilter>[];

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final taggedCounts = CaptureContextTagAnalysis.tagCounts(entries);
    final taggedCount =
        taggedCounts.values.fold<int>(0, (sum, count) => sum + count);
    final distinctTags = taggedCounts.length;
    final untaggedCount = _untaggedCount(eligible);

    if (untaggedCount > 0 &&
        !omitKinds.contains(EvidenceAttentionFilterKind.untagged)) {
      filters.add(
        const EvidenceAttentionFilter(
          kind: EvidenceAttentionFilterKind.untagged,
          label: VisibleArchiveProofCopy.evidenceAttentionFilterUntagged,
          destination: EvidenceAttentionFilterDestination.untaggedDrilldown,
        ),
      );
    }

    final thinTagId = _thinnestContextTagId(taggedCounts);
    if (thinTagId != null &&
        !omitKinds.contains(EvidenceAttentionFilterKind.thinContexts)) {
      filters.add(
        EvidenceAttentionFilter(
          kind: EvidenceAttentionFilterKind.thinContexts,
          label: VisibleArchiveProofCopy.evidenceAttentionFilterThinContexts,
          destination: EvidenceAttentionFilterDestination.thinContextDrilldown,
          contextTagId: thinTagId,
        ),
      );
    }

    if (taggedCount > 0 &&
        distinctTags == 1 &&
        !omitKinds.contains(EvidenceAttentionFilterKind.sameContext)) {
      filters.add(
        const EvidenceAttentionFilter(
          kind: EvidenceAttentionFilterKind.sameContext,
          label: VisibleArchiveProofCopy.evidenceAttentionFilterSameContext,
          destination: EvidenceAttentionFilterDestination.archiveBelief,
        ),
      );
    }

    if (_hasCorrections() &&
        !omitKinds.contains(EvidenceAttentionFilterKind.corrections)) {
      filters.add(
        const EvidenceAttentionFilter(
          kind: EvidenceAttentionFilterKind.corrections,
          label: VisibleArchiveProofCopy.evidenceAttentionFilterCorrections,
          destination: EvidenceAttentionFilterDestination.insightQuality,
        ),
      );
    }

    if (ArchiveInsightFeedbackStore.hiddenInsightCount() > 0 &&
        !omitKinds.contains(EvidenceAttentionFilterKind.hidden)) {
      filters.add(
        const EvidenceAttentionFilter(
          kind: EvidenceAttentionFilterKind.hidden,
          label: VisibleArchiveProofCopy.evidenceAttentionFilterHidden,
          destination: EvidenceAttentionFilterDestination.insightQuality,
        ),
      );
    }

    final visible = omitKinds.isEmpty
        ? filters
        : filters.where((filter) => !omitKinds.contains(filter.kind)).toList();

    if (visible.isEmpty) {
      return EvidenceAttentionFilters.hidden();
    }

    return EvidenceAttentionFilters(
      showCard: true,
      title: VisibleArchiveProofCopy.evidenceAttentionFiltersTitle,
      filters: visible,
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

  static String? _thinnestContextTagId(Map<String, int> taggedCounts) {
    final thin = taggedCounts.entries.where((entry) => entry.value == 1).toList()
      ..sort((a, b) {
        final aLabel = CaptureContextTags.byId(a.key)?.label ?? a.key;
        final bLabel = CaptureContextTags.byId(b.key)?.label ?? b.key;
        return aLabel.compareTo(bLabel);
      });
    if (thin.isEmpty) return null;
    return thin.first.key;
  }

  static bool _hasCorrections() =>
      ArchiveInsightFeedbackStore.totalNotQuiteCount() > 0 ||
      ArchiveInsightFeedbackStore.correctionNoteCount() > 0;
}
