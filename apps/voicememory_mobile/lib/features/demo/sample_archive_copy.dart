import '../../product/archive_positioning_copy.dart';

/// Guided tour copy for the sample archive — example data only.
abstract final class SampleArchiveCopy {
  SampleArchiveCopy._();

  static const emptyStateTitle = 'See a sample archive';
  static const emptyStateSubtitle =
      'Explore how ArchiveMe builds a private pattern map before adding your own moments. '
      '${ArchivePositioningCopy.mapLine}';

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
  static const tourTitle = 'Explore ArchiveMe in 3 steps';
  static const tourCollapse = 'Hide steps';
  static const tourExpand = 'Show steps';
  static const tourDismiss = 'Dismiss for now';

  static const tourStep1Title = 'Start with the archive belief';
  static const tourStep1Body =
      'ArchiveMe shows a cautious belief based on saved moments.';

  static const tourStep2Title = 'Check the evidence map';
  static const tourStep2Body =
      'See where the example moments show up.';

  static const tourStep3Title = 'Open a context';
  static const tourStep3Body =
      'Tap Work or Home to see the example moments behind the count.';

  static const tourStep4Title = 'Review what changed';
  static const tourStep4Body =
      'The review/history section shows how the archive compares moments over time.';

  static const tourStep5Title = 'Go back to your archive';
  static const tourStep5Body =
      'Sample data is only an example. Your real archive stays separate.';

  static const demoShareTitle = 'ArchiveMe sample archive';
  static const demoShareSubtitle = 'Example data only — not your private archive';
  static const demoShareBulletOne =
      'ArchiveMe compares saved moments over time.';
  static const demoShareBulletTwo =
      'It shows cautious beliefs with evidence.';
  static const demoShareBulletThree =
      'It highlights where evidence is strong, thin, or needs attention.';
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

  static const sampleContextBanner =
      'Sample archive — example data only';
  static const sampleContextExampleLabel = 'Example moment';
}
