/// Consumer-facing copy for archive privacy / trust controls.
import 'privacy_copy_policy.dart';

abstract class ArchivePrivacyControlsCopy {
  ArchivePrivacyControlsCopy._();

  static const String cardTitle = 'Your archive is private';

  static const String lockTitle = PrivacyCopyPolicy.lockArchiveMe;
  static const String lockSubtitle =
      'Require Face ID, Touch ID, or a PIN before opening your archive on this device.';

  static const String exportTitle = 'Export my archive';
  static const String exportSubtitle =
      'Download a plain-text copy of your saved moments.';

  static const String deleteTitle = PrivacyCopyPolicy.deleteLocalArchive;
  static const String deleteSubtitle =
      'Permanently remove local entries, drafts, and recordings on this device.';

  static const String cloudTitle = 'Cloud and transcription';
  static const String cloudSubtitle =
      PrivacyCopyPolicy.transcriptionAnalysisWhenUsed;
}

abstract class ArchiveDataFlowCopy {
  ArchiveDataFlowCopy._();

  static const String sheetTitle = 'What stays on this device';

  static const List<String> bodySections = [
    PrivacyCopyPolicy.journalEncryptedAtRest,
    PrivacyCopyPolicy.transcriptionAnalysisWhenUsed,
    'Recording audio may need transcription before ArchiveMe can understand it.',
    'If transcription or cloud features are enabled, only the text needed for that action is sent.',
    '    ArchiveMe does not treat your words as instructions. Your words are private content to analyse, not commands to follow.',
    PrivacyCopyPolicy.exportDeleteAnytime,
  ];

  static const String doneLabel = 'Done';
}
