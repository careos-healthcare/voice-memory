import '../../features/explainable_conclusion/explainable_conclusion.dart';
import '../../features/explainable_conclusion/explainable_conclusion_validator.dart';

/// Pure reduction of one validated conclusion into the two post-save layers:
/// the compact default and the expanded evidence detail.
///
/// Confidence is only ever exposed as a band label. The numeric confidence
/// score never reaches this layer.
final class PostSaveConclusionView {
  PostSaveConclusionView._({
    required this.conclusion,
    required this.label,
    required this.statement,
    required this.strongestEvidence,
    required this.evidenceCount,
    required this.confidenceBandLabel,
    required this.chronology,
    required this.additionalEvidence,
  });

  factory PostSaveConclusionView.of(ValidatedExplainableConclusion conclusion) {
    final value = conclusion.value;
    final evidenceCount = value.evidence
        .map((citation) => citation.entryId)
        .toSet()
        .length;
    final strongest = _strongest(value.evidence);
    final chronology = [...value.evidence]
      ..sort((a, b) {
        final left = a.sourceCapturedAt;
        final right = b.sourceCapturedAt;
        if (left == null && right == null) return 0;
        if (left == null) return 1;
        if (right == null) return -1;
        return left.compareTo(right);
      });
    return PostSaveConclusionView._(
      conclusion: conclusion,
      label: switch (value.kind) {
        ExplainableInsightKind.observation => 'Possible read',
        ExplainableInsightKind.change => 'Possible change',
        ExplainableInsightKind.pattern => 'Possible repeat',
      },
      statement: value.statement,
      strongestEvidence: strongest,
      evidenceCount: evidenceCount,
      confidenceBandLabel: value.confidenceLabel,
      chronology: List.unmodifiable(chronology),
      additionalEvidence: List.unmodifiable(
        value.evidence.where((citation) => !identical(citation, strongest)),
      ),
    );
  }

  final ValidatedExplainableConclusion conclusion;

  /// "Possible read" / "Possible repeat" / "Possible change".
  final String label;
  final String statement;
  final TranscriptEvidenceCitation? strongestEvidence;
  final int evidenceCount;
  final String confidenceBandLabel;
  final List<TranscriptEvidenceCitation> chronology;
  final List<TranscriptEvidenceCitation> additionalEvidence;

  String get evidenceCountLabel =>
      'Based on $evidenceCount saved '
      '${evidenceCount == 1 ? 'moment' : 'moments'}';

  String? get strongestQuote => strongestEvidence?.quote.trim();

  String? get strongestDate =>
      formatFullDate(strongestEvidence?.sourceCapturedAt);

  static TranscriptEvidenceCitation? _strongest(
    List<TranscriptEvidenceCitation> evidence,
  ) {
    if (evidence.isEmpty) return null;
    final supporting = evidence
        .where((citation) => citation.role == TranscriptEvidenceRole.supporting)
        .toList(growable: false);
    final candidates = supporting.isEmpty ? evidence : supporting;
    var best = candidates.first;
    for (final candidate in candidates.skip(1)) {
      if (candidate.confidenceScore > best.confidenceScore) {
        best = candidate;
      } else if (candidate.confidenceScore == best.confidenceScore &&
          candidate.quote.trim().length > best.quote.trim().length) {
        best = candidate;
      }
    }
    return best;
  }

  /// Full, unabbreviated date so evidence is never dated ambiguously.
  static String? formatFullDate(DateTime? value) {
    if (value == null) return null;
    final local = value.toLocal();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  static String? formatAudioTimestamp(int? milliseconds) {
    if (milliseconds == null || milliseconds < 0) return null;
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  static String sourceLabel(EvidenceSourceType type) => switch (type) {
    EvidenceSourceType.voice => 'Voice',
    EvidenceSourceType.text => 'Text',
    EvidenceSourceType.unknown => 'Unknown',
  };

  static String temporalLabel(EvidenceTemporalRole role) => switch (role) {
    EvidenceTemporalRole.then => 'Then',
    EvidenceTemporalRole.now => 'Now',
    EvidenceTemporalRole.single => 'Supporting moment',
  };
}
