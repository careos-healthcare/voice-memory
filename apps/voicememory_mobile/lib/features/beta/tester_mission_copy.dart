/// Copy for beta-only tester onboarding — mission card, settings guide, QA.
abstract final class TesterMissionCopy {
  TesterMissionCopy._();

  static const title = 'Testing ArchiveMe?';

  static const mission = 'Reach first proof.';

  static const step1 = 'Record one real moment.';
  static const step2 = 'Come back when something similar happens.';
  static const step3 = 'Record a third related moment.';
  static const step4 =
      'Check whether first proof feels specific to your own words.';

  static const steps = [step1, step2, step3, step4];

  static const feedbackQuestion =
      'Did ArchiveMe show something repeating in your own words that was worth tracking?';

  static const feedbackSavedBody = 'Beta feedback saved. Thank you.';

  static const entry0Body = 'Step 1: record one real moment.';
  static const entry0StepLabel = '';
  static const entry0Footer = '';

  static const entry1Body = 'Step 1 complete. Next: record something similar.';
  static const entry1StepLabel = '';
  static const entry1Footer = '';

  static const entry2RelatedBody =
      'Step 2 complete. One more related moment unlocks first proof.';
  static const entry2RelatedStepLabel = '';
  static const entry2RelatedFooter = '';

  static const entry2UnrelatedBody =
      'Step 2 still forming. Record the next real moment.';
  static const entry2UnrelatedStepLabel = '';
  static const entry2UnrelatedFooter = '';

  static const entry3ConfirmedBody =
      'First proof reached. Did it feel specific to your own words?';
  static const entry3ConfirmedStepLabel = '';
  static const entry3ConfirmedFooter = '';

  static const entry3UnconfirmedBody =
      'First proof has not appeared yet. Record the next real moment.';
  static const entry3UnconfirmedStepLabel = '';
  static const entry3UnconfirmedFooter = '';

  static const feedbackSavedStepLabel = '';
  static const feedbackSavedFooter = '';

  static const hideForNowCta = 'Hide for now';
  static const hideForTodayCta = 'Hide for today';
}
