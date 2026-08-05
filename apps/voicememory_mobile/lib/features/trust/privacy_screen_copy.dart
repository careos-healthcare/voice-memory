/// In-app privacy and trust copy — ArchiveMe product voice only.
import '../../security/privacy_copy_policy.dart';

abstract class PrivacyScreenCopy {
  PrivacyScreenCopy._();

  static const String screenTitle = 'Privacy';

  static const String intro =
      'Your recordings and reflections are personal. ArchiveMe is private by '
      'default. Some features send audio or text for transcription or analysis '
      'when you use them.';

  static const String privateByDefaultTitle =
      PrivacyCopyPolicy.privateByDefault;
  static const String privateByDefaultBody =
      PrivacyCopyPolicy.journalEncryptedAtRest;

  static const String onDeviceTitle = 'What stays on your device';
  static const String onDeviceBody =
      'Your archive entries, saved details, action items, surfacing choices, '
      'memory controls, packs, pins, and collections are stored locally by default. '
      'Archive metadata and prefs remain on this device in plaintext JSON.';

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
      'personal memory by default. ArchiveMe is not therapy, medical advice, '
      'or emergency support.';

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

  static const String remoteProcessingSectionTitle = 'Remote analysis';
  static const String remoteProcessingSwitchLabel =
      'Send new moments for reflection';
  static const String remoteProcessingSwitchBodyOn =
      "On — a new moment's transcript is sent to compare it against what "
      "you've said before. Turn this off any time; anything already saved "
      'stays exactly as it is.';
  static const String remoteProcessingSwitchBodyOff =
      'Off — new moments are saved on this device only. Turn this on to '
      'get a reflection for what you record next.';
  static const String remoteProcessingConsentedAtPrefix = 'Last turned on ';
  static const String remoteProcessingWithdrawnFootnote =
      'Withdrawing here only changes what happens next — moments already '
      'analyzed keep their existing reflection.';

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
    remoteProcessingSectionTitle,
    remoteProcessingSwitchLabel,
    remoteProcessingSwitchBodyOn,
    remoteProcessingSwitchBodyOff,
    remoteProcessingConsentedAtPrefix,
    remoteProcessingWithdrawnFootnote,
  ];
}

class PrivacySection {
  const PrivacySection({required this.title, required this.body});

  final String title;
  final String body;
}
