/// Three-moment activation copy — cautious proof threshold teaching.
abstract final class ThreeMomentActivationCopy {
  ThreeMomentActivationCopy._();

  static const momentOneLine = 'One moment starts the archive.';

  static const momentTwoLine =
      'A second similar moment gives ArchiveMe something to compare.';

  static const momentThreeLine =
      'Around three real moments, the first useful repeat can appear.';

  static const cautionLine =
      'ArchiveMe usually needs a few real moments before the first useful repeat can appear.';

  static const combinedBody =
      '$momentOneLine $momentTwoLine $momentThreeLine';

  static bool usesCautiousLanguage(String text) {
    final lower = text.toLowerCase();
    return lower.contains('can') ||
        lower.contains('usually') ||
        lower.contains('may') ||
        lower.contains('around');
  }

  static Iterable<String> allVisibleStrings() sync* {
    yield momentOneLine;
    yield momentTwoLine;
    yield momentThreeLine;
    yield cautionLine;
    yield combinedBody;
  }
}
