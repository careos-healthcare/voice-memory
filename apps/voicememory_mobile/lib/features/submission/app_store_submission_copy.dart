import '../../config/app_config.dart';
import '../archive_proof/visible_archive_proof_copy.dart';

/// Deterministic App Store submission prep copy — in-repo only, not user debug UI.
abstract final class AppStoreSubmissionCopy {
  AppStoreSubmissionCopy._();

  static const expectedVersion = '0.2.0';
  static const expectedBuildNumber = 38;
  static const expectedVersionLine = '0.2.0+38';

  static String get typeInsteadLabel => VisibleArchiveProofCopy.typeInsteadCta;

  static const screenshotCaptionSaveMoment = 'Save a private moment';
  static const screenshotCaptionRepeatsOverTime =
      'See what repeats over time';
  static const screenshotCaptionEvidenceNotGuesses =
      'Review evidence, not guesses';
  static const screenshotCaptionPrivateArchive =
      'Explore your private archive';
  static const screenshotCaptionExportWhenChoose =
      'Export only when you choose';
  static const screenshotCaptionSampleArchive =
      'Try Sample Archive with example data';

  static const screenshotCaptions = <String>[
    screenshotCaptionSaveMoment,
    screenshotCaptionRepeatsOverTime,
    screenshotCaptionEvidenceNotGuesses,
    screenshotCaptionPrivateArchive,
    screenshotCaptionExportWhenChoose,
    screenshotCaptionSampleArchive,
  ];

  static const reviewerNoteTypeInstead =
      'ArchiveMe can be tested without microphone access by using Type instead.';
  static const reviewerNoteSampleArchive =
      'Sample Archive uses example data only and does not write to the real journal.';
  static const reviewerNoteRevenueCatPaused =
      'RevenueCat purchases are unavailable until banking setup is complete; the free archive flow remains usable.';
  static const reviewerNotePrivacyControls =
      'Privacy & data controls are available in Settings.';
  static const reviewerNoteShareSafeProof =
      'Share-safe proof does not include raw private entries.';

  static const reviewerNotes = <String>[
    reviewerNoteTypeInstead,
    reviewerNoteSampleArchive,
    reviewerNoteRevenueCatPaused,
    reviewerNotePrivacyControls,
    reviewerNoteShareSafeProof,
  ];

  static const suggestedReviewPathTitle = 'Suggested review path';

  static List<String> get suggestedReviewPathBullets => [
        'Use $typeInsteadLabel if microphone access is unavailable.',
        'Open Sample Archive for example data that never writes to your journal.',
        'Follow Good demo paths inside Sample Archive for screenshots or demos.',
        reviewerNotePrivacyControls,
        'Support and feedback are available from Settings.',
      ];

  static const privacyExplanationTitle = 'Privacy for reviewers';
  static const privacyExplanationBody =
      'Your archive stays on this device. Share-safe proof and export paths never include raw private entries unless you explicitly choose to share them.';

  static const demoPathChecklistTitle = 'Demo path checklist';

  static const demoPathChecklistOpenSampleArchive = 'Open Sample Archive';
  static const demoPathChecklistFollowDemoPaths =
      'Follow Good demo paths inside Sample Archive';
  static const demoPathChecklistOpenEvidenceMap = 'Open Evidence Map';
  static const demoPathChecklistOpenWorkContext = 'Open Work context';
  static const demoPathChecklistCopyDemoSummary = 'Copy demo summary';
  static const demoPathChecklistSupportFeedback =
      'Open Support & feedback for help or issues';

  static List<String> get demoPathChecklist => const [
        demoPathChecklistOpenSampleArchive,
        demoPathChecklistFollowDemoPaths,
        demoPathChecklistOpenEvidenceMap,
        demoPathChecklistOpenWorkContext,
        demoPathChecklistCopyDemoSummary,
        demoPathChecklistSupportFeedback,
      ];

  static String get supportUrl => AppConfig.supportUrl;

  static const supportUrlCheckLabel = 'Support URL';

  /// App Store Connect reviewer notes block — includes support URL line.
  static String buildReviewerNotesBlock() {
    final buffer = StringBuffer();
    for (final note in reviewerNotes) {
      buffer.writeln('• $note');
    }
    buffer.writeln('• $supportUrlCheckLabel: $supportUrl');
    return buffer.toString().trimRight();
  }

  static String buildDemoPathChecklist() {
    final buffer = StringBuffer()..writeln(demoPathChecklistTitle);
    for (final step in demoPathChecklist) {
      buffer.writeln('• $step');
    }
    return buffer.toString().trimRight();
  }

  static String buildPrivacyExplanationBlock() {
    return '$privacyExplanationTitle\n$privacyExplanationBody';
  }
}
