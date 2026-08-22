import 'package:archiveme_mobile/features/evidence_artifact/domain/evidence_proof_models.dart';
import 'package:archiveme_mobile/features/evidence_method/insight.dart';
import 'package:archiveme_mobile/features/evidence_trail/evidence_trail_models.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';

/// Aggregates fact-ledger citation math for beliefs and insights.
abstract final class EvidenceProofCalculator {
  EvidenceProofCalculator._();

  static EvidenceProofArtifact fromInsight(Insight insight) {
    final citations = insight.citedEntries
        .map(
          (entry) => EvidenceProofCitation(
            entryId: entry.entryId,
            quote: _normalizeQuote(entry.rawText),
            recordedAt: entry.createdAt,
          ),
        )
        .toList(growable: false);

    return EvidenceProofArtifact(
      subjectTitle: insight.insightText,
      confidenceBand: insight.confidenceBand,
      stats: _computeStats(citations),
      citations: _sortedCitations(citations),
    );
  }

  static EvidenceProofArtifact fromEvidenceTrail(
    EvidenceTrailPayload payload, {
    PatternMatchConfidenceBand? confidenceBand,
  }) {
    final citations = payload.sources
        .map(
          (source) => EvidenceProofCitation(
            entryId: source.entryId,
            quote: _normalizeQuote(source.excerpt),
            recordedAt: source.recordedAt,
          ),
        )
        .toList(growable: false);

    final resolvedBand = resolveBand(
      explicit: confidenceBand,
      confidencePercent: payload.confidencePercent,
      citationCount: citations.length,
    );

    return EvidenceProofArtifact(
      subjectTitle: payload.title,
      confidenceBand: resolvedBand,
      stats: _computeStats(citations),
      citations: _sortedCitations(citations),
      confidencePercent: payload.confidencePercent,
    );
  }

  static EvidenceProofArtifact fromCitations({
    required String subjectTitle,
    required PatternMatchConfidenceBand confidenceBand,
    required List<EvidenceProofCitation> citations,
    int? confidencePercent,
  }) {
    return EvidenceProofArtifact(
      subjectTitle: subjectTitle,
      confidenceBand: confidenceBand,
      stats: _computeStats(citations),
      citations: _sortedCitations(citations),
      confidencePercent: confidencePercent,
    );
  }

  static PatternMatchConfidenceBand resolveBand({
    required int citationCount, PatternMatchConfidenceBand? explicit,
    int? confidencePercent,
  }) {
    if (explicit != null) return explicit;
    if (confidencePercent != null) {
      return bandFromConfidencePercent(confidencePercent);
    }
    if (citationCount >= 4) return PatternMatchConfidenceBand.solid;
    if (citationCount >= 2) return PatternMatchConfidenceBand.emerging;
    return PatternMatchConfidenceBand.weak;
  }

  static PatternMatchConfidenceBand bandFromConfidencePercent(int percent) {
    if (percent >= 75) return PatternMatchConfidenceBand.strong;
    if (percent >= 55) return PatternMatchConfidenceBand.solid;
    if (percent >= 35) return PatternMatchConfidenceBand.emerging;
    return PatternMatchConfidenceBand.weak;
  }

  static EvidenceProofStats _computeStats(List<EvidenceProofCitation> citations) {
    final count = citations.length;
    if (count == 0) {
      return const EvidenceProofStats(
        totalFrequency: 0,
        spanDays: 0,
        timespanLabel: 'No citations yet',
        frequencyBadgeLabel: 'No detections',
        occurrenceDensityPerWeek: 0,
      );
    }

    if (count == 1) {
      return const EvidenceProofStats(
        totalFrequency: 1,
        spanDays: 0,
        timespanLabel: '1 time',
        frequencyBadgeLabel: 'Detected 1×',
        occurrenceDensityPerWeek: 1,
      );
    }

    final sorted = _sortedCitations(citations);
    final first = sorted.first.recordedAt;
    final last = sorted.last.recordedAt;
    final spanDays = last.difference(first).inDays.abs().clamp(0, 3650);
    final density = count / (spanDays <= 0 ? 1 : spanDays / 7);

    return EvidenceProofStats(
      totalFrequency: count,
      spanDays: spanDays,
      timespanLabel: _formatTimespan(count, spanDays),
      frequencyBadgeLabel: spanDays <= 0
          ? 'Detected $count× on the same day'
          : 'Detected $count× in $spanDays days',
      occurrenceDensityPerWeek: double.parse(density.toStringAsFixed(2)),
    );
  }

  static List<EvidenceProofCitation> _sortedCitations(
    List<EvidenceProofCitation> citations,
  ) {
    final sorted = List<EvidenceProofCitation>.from(citations)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return sorted;
  }

  static String _formatTimespan(int count, int spanDays) {
    if (spanDays <= 0) return '$count times on the same day';
    if (spanDays >= 14) {
      final weeks = (spanDays / 7).round().clamp(1, 520);
      return '$count times over $weeks ${weeks == 1 ? 'week' : 'weeks'}';
    }
    return '$count times over $spanDays ${spanDays == 1 ? 'day' : 'days'}';
  }

  static String _normalizeQuote(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '(No transcript)';
    if (trimmed.startsWith('"') || trimmed.startsWith('“')) return trimmed;
    return '"$trimmed"';
  }
}