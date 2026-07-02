/// Copy for the internal TestFlight tester mission card — debug/beta only.
abstract final class TesterMissionCopy {
  TesterMissionCopy._();

  static const title = 'Test mission';

  static const entry0Body =
      '3-moment proof test. Record one real moment — no need to explain everything.';
  static const entry0StepLabel = 'Step 1 of 3';
  static const entry0Footer =
      'Come back when something similar happens. Ten seconds is enough.';

  static const entry1Body =
      'Record moment 2 when something similar happens. Short is fine.';
  static const entry1StepLabel = 'Step 2 of 3';
  static const entry1Footer =
      'Similar moments let ArchiveMe compare.';

  static const entry2RelatedBody =
      'One more related moment unlocks your first proof.';
  static const entry2RelatedStepLabel = 'Step 3 of 3';
  static const entry2RelatedFooter =
      'The third moment shows the repeat back to you.';

  static const entry2UnrelatedBody =
      'No clear match yet — that is okay. Record the next real moment.';
  static const entry2UnrelatedStepLabel = 'Still looking';
  static const entry2UnrelatedFooter = 'No need to force a pattern.';

  static const entry3ConfirmedBody =
      'First proof reached. Record when this comes back so ArchiveMe can show whether it changes.';
  static const entry3ConfirmedStepLabel = 'First proof reached';
  static const entry3ConfirmedFooter =
      'This is the part I need feedback on.';

  static const entry3UnconfirmedBody =
      'Keep recording real moments until ArchiveMe has enough evidence to show a repeat.';
  static const entry3UnconfirmedStepLabel = 'Still looking';
  static const entry3UnconfirmedFooter = 'Do not force a pattern.';

  static const hideForNowCta = 'Hide for now';
  static const hideForTodayCta = 'Hide for today';
}
