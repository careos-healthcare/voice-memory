/// Copy for the daily archive memory card — returning-user recall only.
abstract final class DailyArchiveMemoryCopy {
  DailyArchiveMemoryCopy._();

  static const watchTitle = 'Did this come back?';

  static const watchBody = 'Last time, your watch target was:';

  static const footer =
      'Record if it came back, changed, faded, or disappeared.';

  static const recordCta = 'Record what happened';

  static const typeInsteadCta = 'Type instead';

  static const notTodayCta = 'Not today';

  static const dontRemindAgainCta = "Don't remind me again";

  static const viewPatternDetailsCta = 'View pattern details';

  static const fallbackTitle = 'Your archive is ready';

  static const fallbackBody =
      'Record one real moment from today. ArchiveMe will compare it with what came before.';

  static String quotedWatchPhrase(String phrase) => "'$phrase'";

  /// Subtext under [watchTitle] on the focused Record watch-target card.
  static String watchSubtext(String phrase) =>
      '$watchBody ${quotedWatchPhrase(phrase)}';

  /// Legacy single-paragraph form — prefer [watchTitle] + [watchSubtext].
  static String watchPrompt(String phrase) =>
      '$watchTitle ${watchSubtext(phrase)}';
}
