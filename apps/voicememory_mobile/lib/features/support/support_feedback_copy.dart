import '../../config/app_config.dart';
import '../archive_proof/visible_archive_proof_copy.dart';

/// Static copy for the Support & Feedback screen.
abstract final class SupportFeedbackCopy {
  SupportFeedbackCopy._();

  static const screenTitle = 'Support & feedback';

  static const settingsTitle = 'Support & feedback';
  static const settingsSubtitle = 'Get help or share what is not working.';

  static const helpGuideLink = 'Support & feedback';

  static const sectionNeedHelpTitle = 'Need help?';
  static const sectionNeedHelpBody =
      'For support, use the ArchiveMe support page.';

  static const sectionReportTitle = 'Report a problem';
  static const sectionReportBody =
      'Tell us what happened, what you expected, and whether it involved '
      'Record, Archive, Sample Archive, Export, or Settings.';

  static const sectionPrivacyTitle = 'Privacy reminder';
  static const sectionPrivacyBulletOne =
      'Do not send private entries unless you choose to include them.';
  static const sectionPrivacyBulletTwo =
      'Share-safe proof does not include raw private entries.';

  static const sectionTestingTitle = 'Useful testing paths';
  static String get sectionTestingBulletOne =>
      'Use $typeInsteadLabel if microphone access is unavailable.';
  static const sectionTestingBulletTwo =
      'Use Sample Archive to explore the product without adding private moments.';

  static const openSupportPageButton = 'Open support page';
  static const copyChecklistButton = 'Copy support checklist';
  static const openHelpGuideButton = 'Open Help & reviewer guide';
  static const openSampleArchiveButton = 'Open Sample Archive';

  static const checklistTitle = 'ArchiveMe support checklist';
  static const checklistCopied = 'Support checklist copied';

  static String get supportUrl => AppConfig.supportUrl;

  static String get typeInsteadLabel => VisibleArchiveProofCopy.typeInsteadCta;

  static String buildChecklist() {
    return '''
$checklistTitle

$sectionReportBody

$sectionPrivacyTitle
• $sectionPrivacyBulletOne
• $sectionPrivacyBulletTwo

$sectionTestingTitle
• $sectionTestingBulletOne
• $sectionTestingBulletTwo

Support: $supportUrl
'''
        .trim();
  }
}
