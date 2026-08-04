/// Copy for first-proof specificity and capture freedom — trust layer only.
abstract final class ProofSpecificityCopy {
  ProofSpecificityCopy._();

  static const title = 'Why ArchiveMe noticed this';

  static const body =
      'ArchiveMe shows this because more than one saved moment pointed '
      'in the same direction.';

  static const evidenceHeading = 'What repeated';

  static const fallbackEvidenceLine =
      'More than one saved moment pointed to the same pattern.';

  static const boundaryLine =
      'ArchiveMe is not saying this defines you. It is only showing what repeated.';

  static const correctionLine = 'You can correct this if it no longer fits.';

  static const differentiationLine =
      'ChatGPT can help with one conversation. ArchiveMe compares moments '
      'you saved over time.';

  static const captureFreedomLine =
      'Record anything: a thought, decision, worry, win, memory, or small moment. '
      'ArchiveMe looks for what returns over time.';

  static const captureFreedomLineCompact =
      'You do not have to record a problem. Save any moment you may want your '
      'future self to understand.';

  static const List<String> all = [
    title,
    body,
    evidenceHeading,
    fallbackEvidenceLine,
    boundaryLine,
    correctionLine,
    differentiationLine,
    captureFreedomLine,
    captureFreedomLineCompact,
  ];
}
