/// Copy for the daily archive memory card — returning-user recall only.
abstract final class DailyArchiveMemoryCopy {
  DailyArchiveMemoryCopy._();

  static const watchTitle = 'Did this come back?';

  static const watchBody = 'Last time, this was the thread to watch:';

  static const footer =
      'Record if it came back, changed, faded, or disappeared.';

  static const recordCta = 'Record what happened';

  static const typeInsteadCta = 'Type instead';

  static const notTodayCta = 'Not today';

  static const viewPatternDetailsCta = 'View pattern details';

  static const fallbackTitle = 'Your archive is ready';

  static const fallbackBody =
      'Record one real moment from today. ArchiveMe will compare it with what came before.';

  static String quotedWatchPhrase(String phrase) => "'$phrase'";

  /// One calm paragraph for the focused returning Record surface.
  static String watchPrompt(String phrase) =>
      'Did this come back? Last time, this was the thread to watch: '
      "'$phrase'. Record if it came back, changed, faded, or disappeared.";
}
