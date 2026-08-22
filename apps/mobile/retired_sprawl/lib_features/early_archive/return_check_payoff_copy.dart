/// Copy for the return-check payoff after a fourth-or-later related save.
abstract final class ReturnCheckPayoffCopy {
  ReturnCheckPayoffCopy._();

  static const evidenceLabel = 'What changed since your first proof';

  static const softerTitle = 'This looked softer since your first proof';
  static const softerBodyFallback =
      'This return still connects to your first repeat. The evidence suggests it may be less urgent than before.';
  static const softerFooter =
      'ArchiveMe will keep watching whether this shift holds.';

  static const strongerTitle = 'This looked stronger since your first proof';
  static const strongerBodyFallback =
      'This return still connects to your first repeat. The evidence suggests it may be showing up with more intensity than before.';
  static const strongerFooter =
      'ArchiveMe is watching whether this changes when it comes back.';

  static const sameTitle = 'This looked about the same';
  static const sameBodyFallback =
      'This return still connects to your first repeat. ArchiveMe has not seen a clear shift yet.';
  static const sameFooter =
      'ArchiveMe is watching whether this changes when it comes back.';

  static const changedTitle = 'This looked different this time';
  static const changedBodyFallback =
      'This return still connects to your first repeat, but something around it looks different from your first proof.';
  static const changedFooter =
      'ArchiveMe tracks what happens when this comes back.';

  static const unknownTitle = 'ArchiveMe added this return';
  static const unknownBody =
      'This moment joins your evidence trail. ArchiveMe needs more returns before it can compare stronger, softer, or about the same since your first proof.';
  static const unknownFooter =
      'ArchiveMe is watching whether this changes when it comes back.';

  static String softerBodyWithPhrase(String phrase) =>
      'This return still connects to “$phrase”. It looked softer than your first proof.';

  static String strongerBodyWithPhrase(String phrase) =>
      'This return still connects to “$phrase”. It looked stronger than your first proof.';

  static String sameBodyWithPhrase(String phrase) =>
      'This return still connects to “$phrase”. So far it looks about the same since your first proof.';

  static String changedBodyWithPhrase(String phrase) =>
      'This return still connects to “$phrase”, but something around it looks different from your first proof.';
}