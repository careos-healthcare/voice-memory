/// Copy for the unified Archive Summary card.
abstract final class ArchiveSummaryCopy {
  ArchiveSummaryCopy._();

  static const title = 'Repeated evidence in your archive';

  static const promise =
      'ArchiveMe tracks repeated evidence from your own words — not conversation history.';

  static const keepsRepeatingLabel = 'Showed up again';
  static const keepsRepeatingFallback =
      'Your archive is still collecting repeated evidence.';

  static const keepsRepeatingForming =
      'This showed up across three moments. ArchiveMe still needs clearer matching words in your archive.';

  static String keepsRepeatingWithPhrase(String phrase) =>
      'ArchiveMe found “$phrase” across your first three moments — evidence from your words.';

  static const loopFormingLabel = 'Loop forming';
  static const changingLabel = 'What changed';
  static const changingFallback =
      'ArchiveMe is watching whether this gets stronger, softer, or about the same since your first proof.';
  static const whatHelpsLabel = 'Appeared to help';
  static const whatHelpsFallback =
      'ArchiveMe has not noticed repeated helpful evidence in your words yet.';
  static const whatHelpsPrefix = 'ArchiveMe noticed this in your words before:';

  static String whatHelpsWithPhrase(String phrase) =>
      'A helpful action appeared: "$phrase". ArchiveMe is watching whether this '
      'shows up again.';

  static const recordNextLabel = 'Record next';
  static const recordNextCta = 'Record the next piece';

  static const recordNextTriggerUnknown =
      'Record what happened before it appeared.';
  static const recordNextThoughtUnknown =
      'Record what your mind said in the moment.';
  static const recordNextActionUnknown = 'Record what you did next.';
  static const recordNextResultUnknown =
      'Record whether it helped, cost you, or changed.';
  static const recordNextChangeUnknown =
      'Record the next return to see what changed.';
  static const recordNextPositiveMissing =
      'Record what showed up as helpful in your words.';

  static const recordNextChangeGuided = 'What changed when this came up again?';
}
