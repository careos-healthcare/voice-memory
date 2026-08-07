/// Guided tour copy for the sample archive — example data only.
abstract final class SampleArchiveCopy {
  SampleArchiveCopy._();

  static const emptyStateTitle = 'See an example first';
  static const emptyStateSubtitle =
      'Example only — Day 1: pressure at work. Day 2: saying yes again. '
      'Day 3: ArchiveMe notices the repeat. Your private archive stays separate.';

  static const settingsTitle = 'View sample archive';
  static const settingsSubtitle =
      'Example data only — your private archive stays untouched.';

  static const screenTitle = 'Sample archive';
  static const bannerTitle = 'Sample archive';
  static const bannerSubtitle = 'Example data — not your private archive';
  static const themeLabel = 'Work focus and decision-making';

  static const exitDone = 'Back to my archive';
  static const exampleOnlySnackbar = 'This preview uses example data only.';

  static const tourLabel = 'Sample tour — example data only';
  static const tourTitle = 'What happens after a few real moments';
  static const tourCollapse = 'Hide steps';
  static const tourExpand = 'Show steps';
  static const tourDismiss = 'Dismiss for now';

  static const tourStep1Title = 'Day 1: save a real moment';
  static const tourStep1Body =
      'Example data only — you save one real moment when something stands out. '
      'ArchiveMe compares it later.';

  static const tourStep2Title = 'Day 2: something similar returns';
  static const tourStep2Body =
      'Example data only — a second similar moment gives ArchiveMe something to compare.';

  static const tourStep3Title = 'Day 3: see what repeated';
  static const tourStep3Body =
      'Example data only — around three moments, ArchiveMe can show what repeated. '
      'Cautiously, not as a guarantee.';

  static const tourStep4Title = 'This is example data only';
  static const tourStep4Body =
      'Nothing here counts as real proof, export, or share. Your private archive stays separate.';

  static const tourStep5Title = 'Go back to your archive';
  static const tourStep5Body =
      'Save real moments when something repeats. ArchiveMe compares them later.';

  static const demoShareTitle = 'ArchiveMe sample archive';
  static const demoShareSubtitle =
      'Example data only — not your private archive';
  static const demoShareBulletOne =
      'After a few real moments, a pattern can appear.';
  static const demoShareBulletTwo =
      'ArchiveMe compares what returned, changed, faded, or got corrected.';
  static const demoShareBulletThree =
      'Example data only — never your private archive.';
  static const demoShareEvidenceMapHeading = 'Sample evidence map:';
  static const demoShareReviewLine =
      'This sample shows how a pattern can appear across contexts.';
  static const demoSharePrivacyFooter = 'No private entries shared.';
  static const demoShareShareButton = 'Share demo summary';
  static const demoShareCopyButton = 'Copy demo summary';
  static const demoShareSubject = 'ArchiveMe sample archive';

  static String demoShareEvidenceMapRow(String label, int count) =>
      '$label: $count ${count == 1 ? 'moment' : 'moments'}';

  static const demoPathsTitle = 'Good demo paths';
  static const demoPathsIntro =
      'Use these example screens for review or demos.';
  static const demoPathsFooterOne =
      'Sample data is separate from your private archive.';
  static const demoPathsFooterTwo =
      'Nothing here is saved to your real archive.';

  static const demoPathStartTitle = '1. Start here: Sample Archive';
  static const demoPathEvidenceMapTitle = '2. Open Evidence Map';
  static const demoPathWorkContextTitle = '3. Open Work context';
  static const demoPathCopySummaryTitle = '4. Copy demo summary';
  static const demoPathBackArchiveTitle = '5. Back to your archive';

  static const sampleContextBanner = 'Sample archive — example data only';
  static const sampleContextExampleLabel = 'Example moment';
}
