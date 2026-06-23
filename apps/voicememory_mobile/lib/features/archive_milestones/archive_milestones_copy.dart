import 'archive_milestones_models.dart';

/// User-facing copy for archive milestones — no streaks or pressure.
abstract final class ArchiveMilestonesCopy {
  ArchiveMilestonesCopy._();

  static const cardTitle = 'Archive milestones';
  static const cardBody =
      'ArchiveMe gets more useful as your archive has more evidence to compare.';

  static const stateDone = 'Done';
  static const stateNow = 'Now';
  static const stateNext = 'Next';

  static const addMomentAction = 'Add a moment';
  static const proPreviewButton = 'See Pro preview';
  static const proLineLongTerm =
      'Longer-term milestone history is where Pro becomes more useful.';

  static const addMomentRoute = '/record';
  static const proPreviewRoute = '/pro-preview';

  static const firstMomentSaved = 'First moment saved';
  static const firstComparisonPossible = 'First comparison possible';
  static const firstCautiousBelief = 'First cautious belief formed';
  static const firstWeeklyReviewReady = 'First weekly review ready';
  static const firstWatchlistTheme = 'First watchlist theme tracked';
  static const firstReturnRitual = 'First return ritual set';
  static const firstShareSafeProof = 'First export/share-safe proof ready';
  static const longTermArchiveBuilding = 'Long-term archive building at 10+ entries';

  static String labelFor(ArchiveMilestoneId id) => switch (id) {
        ArchiveMilestoneId.firstMomentSaved => firstMomentSaved,
        ArchiveMilestoneId.firstComparisonPossible => firstComparisonPossible,
        ArchiveMilestoneId.firstCautiousBelief => firstCautiousBelief,
        ArchiveMilestoneId.firstWeeklyReviewReady => firstWeeklyReviewReady,
        ArchiveMilestoneId.firstWatchlistTheme => firstWatchlistTheme,
        ArchiveMilestoneId.firstReturnRitual => firstReturnRitual,
        ArchiveMilestoneId.firstShareSafeProof => firstShareSafeProof,
        ArchiveMilestoneId.longTermArchiveBuilding => longTermArchiveBuilding,
      };

  static String stateLabel(ArchiveMilestoneRowState state) => switch (state) {
        ArchiveMilestoneRowState.done => stateDone,
        ArchiveMilestoneRowState.now => stateNow,
        ArchiveMilestoneRowState.next => stateNext,
      };

  static Iterable<String> allVisibleCopy() sync* {
    yield cardTitle;
    yield cardBody;
    yield stateDone;
    yield stateNow;
    yield stateNext;
    yield addMomentAction;
    yield proPreviewButton;
    yield proLineLongTerm;
    for (final id in ArchiveMilestoneId.values) {
      yield labelFor(id);
    }
  }
}
