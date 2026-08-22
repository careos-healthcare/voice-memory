/// Static explainability copy for proof surface disclosures.
abstract final class ProofSurfaceWhyAppearedCopy {
  ProofSurfaceWhyAppearedCopy._();

  static const linkLabel = 'Why this appeared';

  static const firstProof =
      'ArchiveMe saw related evidence across three moments.';
  static const archiveBelief =
      'your archive has enough repeated evidence to form a provisional belief.';
  static const whatChanged =
      'ArchiveMe compared this return with your first proof.';
  static const patternChanged =
      'this return looked meaningfully different from earlier evidence.';
  static const helpfulAction =
      'a concrete action showed up near a softer or changed return.';
  static const evidenceTimeline =
      'ArchiveMe connected related evidence across your saved moments.';

  static String line(String body) => '$linkLabel: $body';

  static List<String> get allLines => [
    line(firstProof),
    line(archiveBelief),
    line(whatChanged),
    line(patternChanged),
    line(helpfulAction),
    line(evidenceTimeline),
  ];
}