/// Copy for the capacity yes loop card — cautious evidence language only.
abstract final class CapacityLoopCopy {
  CapacityLoopCopy._();

  static const route = '/capacity-loop';
  static const recordRoute = '/record';
  static const archiveHomeRoute = '/archive-belief';

  static const title = 'Your yes loop';
  static const subtitle =
      'A private card for the pattern behind saying yes with no capacity.';

  static String evidenceCountLabel(int count) =>
      'Built from $count saved moment${count == 1 ? '' : 's'}';

  static const emptyStateBody =
      'Save 3 real moments where you said yes too quickly. ArchiveMe will start building your yes loop.';

  static const formingWhatRepeated =
      'Your archive is starting to show moments where agreeing may have come before checking capacity.';
  static const formingCostLater =
      'Cost later is still forming — save another moment to see what may repeat afterward.';
  static const watchNext =
      'Before agreeing, save the moment when you feel the pull to say yes.';

  static String whatRepeatedWithTheme(String theme) =>
      'You have saved moments where $theme may keep showing up before you say yes.';
  static const whatRepeatedGeneric =
      'You have saved moments where agreeing before checking room may be forming.';
  static const whatRepeatedStrong =
      'This may be forming: agreeing, helping, or taking something on before checking capacity.';

  static String costLaterWithCount(int count) =>
      'In $count saved moment${count == 1 ? '' : 's'}, pressure or depletion may have showed up afterward.';
  static const costLaterForming =
      'Cost later is still forming — the next moment may show what agreeing took from you.';
  static const costLaterUnavailable =
      'Cost later is not clear yet — save another moment after you agree.';

  static String costLaterRecordedCount(int count) =>
      'Later cost recorded on $count moment${count == 1 ? '' : 's'}.';
  static const costLaterStrengthenPrompt =
      'Add a later-cost check-in to strengthen this loop.';

  static String costEvidenceOnScreen(int count) =>
      '$count saved moment${count == 1 ? '' : 's'} had a later cost';

  static String outcomeMarkedCount(int count) =>
      'Outcome marked on $count moment${count == 1 ? '' : 's'}.';

  static String outcomesMarkedAfterPause(int count) =>
      'You marked $count outcome${count == 1 ? '' : 's'} after pausing.';

  static const outcomeStrengthenPrompt =
      'Mark what happened after a pause to strengthen this loop.';

  static const patternMayHaveChanged =
      'Some moments show the pattern may have changed.';

  static const saveYesMomentCta = 'Save a yes moment';
  static const saveYesMomentShortCta = 'Save yes moment';
  static const reviewLoopCta = 'Review the loop';

  static const recordPromptTitle = 'About to say yes?';
  static const recordPromptBody = 'Save the moment first.';

  static const shareCopy =
      'I caught a yes loop before it repeated. No private entries shared.';

  static const screenshotTitle = 'Your yes loop';
  static const screenshotSubtitle =
      'A private card built from saved moments — no journal text shown.';
  static const screenshotEvidence = 'Built from 2 saved moments';
  static const screenshotWhatRepeated =
      'Your archive is starting to show a yes-before-capacity pattern.';
  static const screenshotCostLater =
      'Cost later may be forming across saved moments.';
  static const screenshotWatchNext = watchNext;

  static const loopDiagramTrigger = 'Trigger';
  static const loopDiagramSaidYes = 'I said yes';
  static const loopDiagramCostLater = 'Cost later';
  static const loopDiagramRepeated = 'What repeated';
  static const loopDiagramWatchNext = 'What to watch next';
}
