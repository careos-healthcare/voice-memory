import '../features/archive_evidence/archive_evidence.dart';
import '../features/archive_v1/archive_v1_models.dart';
import '../models/journal_entry.dart';
import 'archive_paywall_copy.dart';

/// User-specific stats for archive paywall (Variant B production).
class ArchivePaywallStats {
  const ArchivePaywallStats({
    required this.recordingCount,
    required this.spanDays,
    required this.recurringThemeCount,
    required this.activeTheoryCount,
    required this.changeCount,
    required this.contradictionCount,
    this.theoryStatement,
    this.theoryConfidencePercent,
    this.theoryEvidenceCount,
  });

  final int recordingCount;
  final int spanDays;
  final int recurringThemeCount;
  final int activeTheoryCount;
  /// Detected shifts since last archive review ([ArchiveChangeFeedView.totalChangeCount]).
  final int changeCount;
  final int contradictionCount;
  final String? theoryStatement;
  final int? theoryConfidencePercent;
  final int? theoryEvidenceCount;

  bool get hasTheoryPreview =>
      theoryStatement != null &&
      theoryStatement!.trim().length >= 12 &&
      (theoryConfidencePercent ?? 0) >= 15 &&
      (theoryEvidenceCount ?? 0) >= 3;

  bool get hasRichStats => recordingCount >= 5;

  bool get hasPreCtaCounts =>
      hasRichStats &&
      (recurringThemeCount > 0 ||
          activeTheoryCount > 0 ||
          changeCount > 0 ||
          contradictionCount > 0);

  bool get hasIntelligenceProof =>
      recurringThemeCount > 0 || activeTheoryCount > 0 || changeCount > 0;

  String get spanLabel {
    if (spanDays < 45) {
      final d = spanDays < 1 ? 1 : spanDays;
      return '$d ${d == 1 ? 'day' : 'days'}';
    }
    if (spanDays < 730) {
      final m = (spanDays / 30).round().clamp(1, 24);
      return '$m ${m == 1 ? 'month' : 'months'}';
    }
    final y = (spanDays / 365).round().clamp(1, 50);
    return '$y ${y == 1 ? 'year' : 'years'}';
  }

  /// Variant B subheadline (no recording counts — those are in hero).
  String subheadlineVariantB() {
    return '${ArchivePaywallCopy.subheadlineBParagraph1}\n\n'
        '${ArchivePaywallCopy.subheadlineBParagraph2}';
  }

  /// Variant A/C: legacy combined subhead when enough recordings.
  String subheadlineLegacy() {
    if (!hasRichStats) return ArchivePaywallCopy.subheadlineA;
    return 'Generated from $recordingCount '
        'recording${recordingCount == 1 ? '' : 's'} across $spanLabel.\n\n'
        '${ArchivePaywallCopy.subheadlineA}';
  }

  String subheadlineFor(ArchivePaywallVariant variant) => switch (variant) {
        ArchivePaywallVariant.b => subheadlineVariantB(),
        _ => subheadlineLegacy(),
      };

  /// Hero line: "127 recordings" / "6 months" (Variant B).
  String heroRecordingLine() {
    final n = recordingCount;
    return '$n recording${n == 1 ? '' : 's'}';
  }

  String heroSpanLine() => spanLabel;

  /// Variant B pre-CTA with pattern / theory / contradiction counts.
  String preCtaVariantB() {
    if (!hasPreCtaCounts) return ArchivePaywallCopy.preCtaFallback;
    final lines = <String>['ArchiveMe has noticed:'];
    if (recurringThemeCount > 0) {
      lines.add(
        '$recurringThemeCount recurring '
        'pattern${recurringThemeCount == 1 ? '' : 's'}',
      );
    }
    if (activeTheoryCount > 0) {
      lines.add(
        '$activeTheoryCount recurring '
        'theme${activeTheoryCount == 1 ? '' : 's'}',
      );
    }
    if (changeCount > 0) {
      lines.add(
        '$changeCount change${changeCount == 1 ? '' : 's'} over time',
      );
    }
    if (contradictionCount > 0) {
      lines.add(
        '$contradictionCount moment${contradictionCount == 1 ? '' : 's'} '
        'when patterns pulled differently',
      );
    }
    return lines.join('\n');
  }

  String preCtaLegacy() {
    if (!hasRichStats) return ArchivePaywallCopy.preCtaFallback;
    return 'ArchiveMe has reviewed $recordingCount '
        'reflection${recordingCount == 1 ? '' : 's'} and noticed '
        '$recurringThemeCount recurring '
        'pattern${recurringThemeCount == 1 ? '' : 's'}.';
  }

  String preCtaFor(ArchivePaywallVariant variant) => switch (variant) {
        ArchivePaywallVariant.b => preCtaVariantB(),
        _ => preCtaLegacy(),
      };

  static ArchivePaywallStats fromEntries({
    required List<JournalEntry> entries,
    ArchiveV1View? archiveV1,
  }) {
    final eligible = archiveEligibleEvidenceEntries(entries);
    final count = eligible.length;

    var spanDays = 1;
    if (eligible.length >= 2) {
      final sorted = [...eligible]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      spanDays = sorted.last.createdAt.difference(sorted.first.createdAt).inDays;
      if (spanDays < 1) spanDays = 1;
    }

    final themes = <String>{};
    for (final e in eligible) {
      for (final t in e.reflection.recurringThemes) {
        final label = t.trim().toLowerCase();
        if (label.length >= 2) themes.add(label);
      }
    }

    final ranking = archiveV1?.theoryRanking;
    var activeTheories = 0;
    if (ranking?.primaryTheory != null) activeTheories += 1;
    activeTheories += ranking?.secondaryTheories.length ?? 0;
    if (activeTheories == 0 && archiveV1?.theory != null) {
      activeTheories = 1;
    }

    final theory = archiveV1?.theory;
    final feed = archiveV1?.changeFeed;
    final changeCount = feed != null && feed.hasBaseline && feed.hasChanges
        ? feed.totalChangeCount
        : 0;

    return ArchivePaywallStats(
      recordingCount: count,
      spanDays: spanDays,
      recurringThemeCount: themes.length,
      activeTheoryCount: activeTheories,
      changeCount: changeCount,
      contradictionCount: archiveV1?.contradictions.length ?? 0,
      theoryStatement: theory?.statement,
      theoryConfidencePercent: theory?.confidencePercent,
      theoryEvidenceCount: theory?.evidenceCount,
    );
  }
}
