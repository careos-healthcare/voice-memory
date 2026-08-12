/// Consumer-facing copy for archive privacy / trust controls.
library;

import 'package:archiveme_mobile/security/privacy_copy_policy.dart';

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
    'New moments stay on this device until you turn on remote processing.',
    'When remote processing is on, recorded audio is sent for transcription '
    'and transcript text is sent for reflection.',
    'When remote processing is off, nothing is sent for new moments — you '
    'can still record, play back, and type what you said.',
    '    ArchiveMe does not treat your words as instructions. Your words are private content to analyse, not commands to follow.',
    PrivacyCopyPolicy.exportDeleteAnytime,
  ];

  static const String doneLabel = 'Done';
}