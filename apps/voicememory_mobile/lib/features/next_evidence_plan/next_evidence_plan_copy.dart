/// User-facing copy for the next evidence plan — no pressure or certainty.
import '../pro_value/pro_value_copy.dart';

abstract final class NextEvidencePlanCopy {
  NextEvidencePlanCopy._();

  static const cardTitle = 'Next evidence plan';

  static const starterTitle = 'Next evidence plan';
  static const starterBody =
      'Save one moment first. ArchiveMe will suggest what kind of evidence to add next.';

  static const introBody =
      'Your archive will become clearer if you add one moment when this shows up again.';

  static const oneEntryBody =
      'Add one more moment when this shows up again.';
  static const twoEntriesBody =
      'Add the moment that confirms, changes, or challenges this pattern.';
  static const beliefTestBody =
      'Add evidence that tests whether this belief still fits.';
  static const weeklyReviewBody =
      'Add one moment that would make next week\'s review clearer.';

  static const extraDetailSuggestion =
      'Next time, add one extra detail: what happened, where, or what changed.';
  static const contextImprovementSuggestion =
      'Tag or add a moment from a different context.';
  static const usefulEntryHint =
      'One useful next entry: what happened, where it showed up, and what changed.';

  static const addMomentAction = 'Add a moment';
  static const reviewWatchlistAction = 'Review watchlist';
  static const proPreviewButton = ProValueCopy.proPreviewButton;
  static const proLineLongTerm = ProValueCopy.cardProLine;

  static const addMomentRoute = '/record';
  static const proPreviewRoute = ProValueCopy.proPreviewRoute;

  static String watchingForLine(String label) => 'You are watching for: $label.';

  static String watchlistPlanBody(String label) =>
      'Add a moment when \'$label\' shows up again.';

  static String returnRitualLine(String phrase) =>
      'Use your return ritual: $phrase.';

  static Iterable<String> allVisibleCopy() sync* {
    yield cardTitle;
    yield starterTitle;
    yield starterBody;
    yield introBody;
    yield oneEntryBody;
    yield twoEntriesBody;
    yield beliefTestBody;
    yield weeklyReviewBody;
    yield extraDetailSuggestion;
    yield contextImprovementSuggestion;
    yield usefulEntryHint;
    yield addMomentAction;
    yield reviewWatchlistAction;
    yield proPreviewButton;
    yield proLineLongTerm;
    yield watchingForLine('Unclear decisions');
    yield watchlistPlanBody('Unclear decisions');
    yield returnRitualLine('At the end of the workday');
  }
}
