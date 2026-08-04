import 'proof_specificity_copy.dart';

/// Resolved specificity explanation — metadata and safe display labels only.
class ProofSpecificityResult {
  const ProofSpecificityResult({
    required this.shouldShow,
    required this.entryCount,
    required this.source,
    required this.hasConfirmedRepeat,
    required this.hasBeliefSurface,
    required this.evidenceAnchorCount,
    required this.title,
    required this.body,
    required this.evidenceAnchors,
    required this.usesFallbackEvidenceLine,
    required this.boundaryLine,
    required this.correctionLine,
    required this.differentiationLine,
  });

  final bool shouldShow;
  final int entryCount;
  final String source;
  final bool hasConfirmedRepeat;
  final bool hasBeliefSurface;
  final int evidenceAnchorCount;
  final String title;
  final String body;
  final List<String> evidenceAnchors;
  final bool usesFallbackEvidenceLine;
  final String boundaryLine;
  final String correctionLine;
  final String differentiationLine;

  factory ProofSpecificityResult.hidden({
    required String source,
    int entryCount = 0,
  }) => ProofSpecificityResult(
    shouldShow: false,
    entryCount: entryCount,
    source: source,
    hasConfirmedRepeat: false,
    hasBeliefSurface: false,
    evidenceAnchorCount: 0,
    title: ProofSpecificityCopy.title,
    body: ProofSpecificityCopy.body,
    evidenceAnchors: const [],
    usesFallbackEvidenceLine: true,
    boundaryLine: ProofSpecificityCopy.boundaryLine,
    correctionLine: ProofSpecificityCopy.correctionLine,
    differentiationLine: ProofSpecificityCopy.differentiationLine,
  );
}
