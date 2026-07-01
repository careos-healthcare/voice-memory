/// Copy for the return-check payoff after a fourth-or-later related save.
abstract final class ReturnCheckPayoffCopy {
  ReturnCheckPayoffCopy._();

  static const evidenceLabel = 'Compared with your first proof';

  static const softerTitle = 'This looked softer than before';
  static const softerBodyFallback =
      'This return still connects to your first repeat, but the evidence suggests it may be less urgent than before.';
  static const softerFooter =
      'Keep recording when it shows up — ArchiveMe will watch whether the shift continues.';

  static const strongerTitle = 'This looked stronger than before';
  static const strongerBodyFallback =
      'This return still connects to your first repeat, and the evidence suggests it may be showing up more strongly than before.';
  static const strongerFooter =
      'That does not mean you failed. It gives ArchiveMe a clearer signal to track.';

  static const sameTitle = 'This looked about the same';
  static const sameBodyFallback =
      'This return still connects to your first repeat. ArchiveMe has not seen a clear shift yet.';
  static const sameFooter =
      'A few more returns will make the pattern clearer.';

  static const changedTitle = 'Something changed this time';
  static const changedBodyFallback =
      'This return still connects to your first repeat, but something around it looks different from the first proof.';
  static const changedFooter =
      'This is the kind of change ArchiveMe is built to track.';

  static const unknownTitle = 'ArchiveMe added this return';
  static const unknownBody =
      'This moment has been added to your evidence trail. ArchiveMe needs more returns before it can say whether the repeat is stronger, softer, or changing.';
  static const unknownFooter =
      'Keep recording real moments. Do not force a pattern.';

  static String softerBodyWithPhrase(String phrase) =>
      'This return still connects to “$phrase”, but the evidence suggests it may be less urgent than your first proof.';

  static String strongerBodyWithPhrase(String phrase) =>
      'This return still connects to “$phrase”, and the evidence suggests it may be showing up more strongly than before.';

  static String sameBodyWithPhrase(String phrase) =>
      'This return still connects to “$phrase”. ArchiveMe has not seen a clear shift yet.';

  static String changedBodyWithPhrase(String phrase) =>
      'This return still connects to “$phrase”, but something around it looks different from the first proof.';
}
