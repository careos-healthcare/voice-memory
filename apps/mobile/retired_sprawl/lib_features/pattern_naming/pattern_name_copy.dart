/// User-facing copy for pattern name confirmation and rename.
abstract final class PatternNameCopy {
  PatternNameCopy._();

  static const prompt = 'Does this feel right?';
  static const currentLabelPrefix = 'ArchiveMe calls this:';

  static const yesCta = 'Yes';
  static const renameCta = 'Rename';

  static const renameSheetTitle = 'Rename this pattern';
  static const renameSheetHelper =
      'Use words that make sense to you. The evidence stays the same.';
  static const renameFieldLabel = 'Pattern name';
  static const saveNameCta = 'Save name';
  static const cancelCta = 'Cancel';

  static const savedMessage = 'Pattern name saved';

  static String currentLabelLine(String patternLabel) =>
      '$currentLabelPrefix\n“$patternLabel”';
}