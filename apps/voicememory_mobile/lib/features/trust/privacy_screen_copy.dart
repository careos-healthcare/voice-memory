/// In-app privacy and trust copy — ArchiveMe product voice only.
import '../../security/privacy_copy_policy.dart';

abstract class PrivacyScreenCopy {
  PrivacyScreenCopy._();

  static const String screenTitle = 'Privacy';

  static const String intro =
      'Your archive is private by default. ArchiveMe only sends data for '
      'transcription, analysis, sync, or account features when those features '
      'are used.';

  static const String privateByDefaultTitle = PrivacyCopyPolicy.privateByDefault;
  static const String privateByDefaultBody =
      'Your entries stay on this device unless you choose account sync or backup.';

  static const String onDeviceTitle = 'What stays on your device';
  static const String onDeviceBody =
      'Your archive entries, saved details, action items, surfacing choices, '
      'memory controls, packs, pins, and collections are stored locally by default.';

  static const String aiProcessingTitle = 'AI transcription and analysis';
  static const String aiProcessingBody =
      'When you record, ArchiveMe may send audio or transcript text to the app '
      'backend so it can transcribe and organize what you said. The result is '
      'returned to your archive.';

  static const String encryptedBackupTitle = 'Optional encrypted backup';
  static const String encryptedBackupBody =
      'If you sign in and enable sync, backup data is encrypted before it is '
      'stored. Sync is optional.';

  static const String doesNotDoTitle = 'What ArchiveMe does not do';
  static const String doesNotDoBody =
      'ArchiveMe does not sell your reflections. ArchiveMe does not include '
      'recording text in analytics. ArchiveMe does not turn every entry into '
      'personal memory by default.';

  static const String controlsTitle = 'Your controls';
  static const String controlsBody =
      'You can mark entries as Hypothetical, Not about me, Sensitive, '
      'Do not surface, Preserve original, Keep separate, or Treat as new.';

  static const String processingProvidersTitle = 'Processing providers';
  static const String processingProvidersBody =
      'ArchiveMe may use trusted processing providers for transcription, '
      'analysis, account, billing, or crash diagnostics. Provider names may '
      'appear in the full privacy policy where required.';

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
