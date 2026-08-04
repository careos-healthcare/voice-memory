/// In-app privacy and trust copy — ArchiveMe product voice only.
library;

import '../../security/privacy_copy_policy.dart';

abstract class PrivacyScreenCopy {
  PrivacyScreenCopy._();

  static const String screenTitle = 'Privacy';

  static const String intro =
      'Your recordings and saved moments are personal. ArchiveMe is private by '
      'default. Some features send audio or text for transcription or analysis '
      'when you use them.';

  static const String privateByDefaultTitle =
      PrivacyCopyPolicy.privateByDefault;
  static const String privateByDefaultBody =
      PrivacyCopyPolicy.journalEncryptedAtRest;

  static const String onDeviceTitle = 'What stays on your device';
  static const String onDeviceBody =
      'Your archive entries, saved details, action items, surfacing choices, '
      'memory controls, packs, pins, and collections are stored locally by '
      'default. Processing preferences use platform secure storage.';

  static const String aiProcessingTitle = 'Transcription and analysis';
  static const String aiProcessingBody =
      'On-device transcription works without uploading audio. If you choose '
      'online transcription, audio is sent after its disclosure. Interpretation '
      'is a separate choice and disclosure that sends saved text and eligible '
      'prior evidence. Declining either option still saves the original.';

  static const String encryptedBackupTitle = 'Optional encrypted backup';
  static const String encryptedBackupBody =
      'If you sign in and enable sync, backup data is encrypted before it is '
      'stored with a key held by this device. Sync is optional, and the cloud '
      'copy cannot be recovered if that device-held key is lost.';

  static const String doesNotDoTitle = 'What ArchiveMe does not do';
  static const String doesNotDoBody =
      'ArchiveMe does not sell your saved moments. Firebase usage analytics '
      'receives only catalogued product actions and coarse buckets — never '
      'recordings, saved text, generated titles or topics, raw identifiers, '
      'email addresses, or account tokens. ArchiveMe does not turn every entry '
      'into personal memory by default. ArchiveMe is not therapy, medical '
      'advice, or emergency support.';

  static const String controlsTitle = 'Your controls';
  static const String controlsBody =
      'You can mark entries as Hypothetical, Not about me, Sensitive, '
      'Do not surface, Preserve original, Keep separate, or Treat as new.';

  static const String processingProvidersTitle = 'Processing providers';
  static const String processingProvidersBody =
      'ArchiveMe may use trusted processing providers for transcription, '
      'analysis, account, billing, or crash diagnostics. Provider names may '
      'appear in the full privacy policy where required. Provider retention '
      'depends on those providers and is not proven by deleting local data.';

  static const String fullPolicyLink = 'Full privacy policy online';

  static const List<PrivacySection> sections = [
    PrivacySection(title: privateByDefaultTitle, body: privateByDefaultBody),
    PrivacySection(title: onDeviceTitle, body: onDeviceBody),
    PrivacySection(title: aiProcessingTitle, body: aiProcessingBody),
    PrivacySection(title: encryptedBackupTitle, body: encryptedBackupBody),
    PrivacySection(title: doesNotDoTitle, body: doesNotDoBody),
    PrivacySection(title: controlsTitle, body: controlsBody),
  ];

  static const List<String> all = [
    screenTitle,
    intro,
    privateByDefaultTitle,
    privateByDefaultBody,
    onDeviceTitle,
    onDeviceBody,
    aiProcessingTitle,
    aiProcessingBody,
    encryptedBackupTitle,
    encryptedBackupBody,
    doesNotDoTitle,
    doesNotDoBody,
    controlsTitle,
    controlsBody,
    processingProvidersTitle,
    processingProvidersBody,
    fullPolicyLink,
  ];
}

class PrivacySection {
  const PrivacySection({required this.title, required this.body});

  final String title;
  final String body;
}
