/// Copy for the post-save return check answer question at entry four+.
abstract final class PostSaveReturnCheckAnswerCopy {
  PostSaveReturnCheckAnswerCopy._();

  static const label = 'Return check';

  static const title = 'Did this feel different from your first proof?';

  static const bodyFallback =
      'ArchiveMe matched this to your first repeat. Your answer helps it track whether the repeat is changing.';

  static const footer = 'One tap is enough.';

  static String bodyWithPhrase(String phrase) =>
      'ArchiveMe matched this to “$phrase”. Your answer helps it track whether the repeat is changing.';
}
