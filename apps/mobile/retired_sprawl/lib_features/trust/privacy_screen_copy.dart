/// In-app privacy and trust copy — Thoughtprint product voice only.
library;

import 'package:archiveme_mobile/security/privacy_claim_catalogue.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';

abstract class PrivacyScreenCopy {
  PrivacyScreenCopy._();

  static const String screenTitle = 'Privacy';

  static const String intro =
      'Your recordings and reflections are personal. Thoughtprint is private by '
      'default. Audio and transcript text are sent only when you turn on '
      'remote processing for a new entry.';

  /// First thing on the privacy disclosure — scoped to processing vs sync,
  /// not a blanket "nothing leaves this phone."
  ///
  /// Remote processing is `RemoteProcessingConsentStore` plus the analyze /
  /// transcribe uploads. Pattern badges on already-saved entries are local
  /// Dart over local text; they are not what this block describes, and this
  /// block does not claim a model runs on the phone. Sync is
  /// `encrypted_sync_service.dart` uploading ciphertext.
  static const String whereWordsGoTitle = 'What can leave this phone';

  static const String whereWordsGoBody =
      'Writing out a recording, or reading it against what you said before, '
      'only happens off this phone if you turn on remote processing. Sync is '
      'a different choice: if you sign in and back up, an encrypted copy can '
      'leave this phone, and the server cannot read it. While remote '
      'processing is off, those new words are not sent for a transcript or a '
      'read.';

  static const String privateByDefaultTitle =
      PrivacyCopyPolicy.privateByDefault;

  /// Storage protection is a runtime property of the build
  /// (`SecureSqliteLockService.encryptionEnabled`, which has an "unavailable"
  /// state), so this points at the live status instead of asserting a fixed
  /// one, and it names no storage engine — the search index lives outside the
  /// journal store.
  ///
  /// The pointer names privacy settings, not "this screen". `PrivacyScreen`
  /// renders no `EncryptionStatusCard`; the live report is on
  /// `/privacy-security`.
  static const String privateByDefaultBody =
      '${PrivacyClaimCatalogue.remoteProcessingIsAChoice} '
      '${PrivacyClaimCatalogue.momentsStayLocal} '
      '${PrivacyClaimCatalogue.storageProtectionReportedLive}';

  static const String placeLookupDisclosure =
      'The place name is looked up by Apple or Google; the location itself is stored only on your phone.';

  static const String placeLookupTitle = 'Place names';

  static const String onDeviceTitle = 'What stays on your device';
  static const String onDeviceBody =
      'Your archive entries, recorded details, action items, surfacing choices, '
      'memory controls, packs, pins, and collections are stored locally by default. '
      'Archive metadata and prefs stay on this device as well.';

  static const String aiProcessingTitle = 'Cloud transcription and analysis';
  static const String aiProcessingBody =
      'When you record, Thoughtprint may send audio or transcript text to the '
      'app backend so it can transcribe and organize what you said. The result '
      'is returned to your archive. Google Gemini is the AI processor used for '
      'cloud features.';

  static const String encryptedBackupTitle = 'Optional encrypted backup';
  static const String encryptedBackupBody =
      'If you sign in and enable sync, backup data is encrypted before it is '
      'uploaded, using a key held on this device. The server stores that '
      'backup as ciphertext. Sync is optional.';

  static const String doesNotDoTitle = 'What Thoughtprint does not do';
  static const String doesNotDoBody =
      'Thoughtprint does not sell your reflections. Thoughtprint does not include '
      'recording text in analytics. Thoughtprint does not turn every entry into '
      'personal memory by default. Thoughtprint is not therapy, medical advice, '
      'or emergency support.';

  /// Heading for the per-entry marking vocabulary.
  ///
  /// Not "Your controls": the Privacy & Trust Centre already has a heading by
  /// that name over its action tiles, and after `/privacy` migrated into that
  /// screen both would render on one scroll. This one is about how a single
  /// entry is treated, so it says so.
  static const String controlsTitle = 'Ways to mark an entry';
  static const String controlsBody =
      'You can mark entries as Hypothetical, Not about me, Sensitive, '
      'Do not surface, Preserve original, Keep separate, or Treat as new.';

  /// Names the AI processor for cloud features.
  ///
  /// The first sentence is the website `AI_TRANSCRIPTION_ANALYSIS_SUMMARY`:
  /// a recording may be sent to the backend, and Google Gemini is the
  /// processor used for cloud features. The ciphertext sentence stays
  /// separate because encrypted backup uploads data the server cannot read.
  /// The tile stays collapsed until tapped.
  static const String processingProvidersTitle = 'Processing providers';
  static const String processingProvidersBody =
      '$aiProcessingBody Encrypted backup is separate: sync uploads ciphertext, '
      'so the server holds backup data it cannot read.';

  static const String fullPolicyLink = 'Full privacy policy online';

  static const String remoteProcessingSectionTitle = 'Remote processing';
  static const String remoteProcessingSwitchLabel =
      'Send new entries for transcription and reflection';
  static const String remoteProcessingSwitchBodyOn =
      'On — a new moment\'s audio and transcript may be sent to transcribe '
      'and compare it against what you\'ve said before. Turn this off any '
      'time; anything already recorded stays exactly as it is.';
  static const String remoteProcessingSwitchBodyOff =
      'Off — new entries are recorded on this device only. Nothing is sent '
      'for transcription or reflection until you turn this on.';
  static const String remoteProcessingConsentedAtPrefix = 'Last turned on ';
  static const String remoteProcessingWithdrawnFootnote =
      'Withdrawing here only changes what happens next — entries already '
      'analyzed keep their existing reflection.';

  static const List<PrivacySection> sections = [
    PrivacySection(title: privateByDefaultTitle, body: privateByDefaultBody),
    PrivacySection(title: onDeviceTitle, body: onDeviceBody),
    PrivacySection(title: placeLookupTitle, body: placeLookupDisclosure),
    PrivacySection(title: aiProcessingTitle, body: aiProcessingBody),
    PrivacySection(title: encryptedBackupTitle, body: encryptedBackupBody),
    PrivacySection(title: doesNotDoTitle, body: doesNotDoBody),
    PrivacySection(title: controlsTitle, body: controlsBody),
  ];

  static const List<String> all = [
    screenTitle,
    intro,
    whereWordsGoTitle,
    whereWordsGoBody,
    privateByDefaultTitle,
    privateByDefaultBody,
    onDeviceTitle,
    onDeviceBody,
    placeLookupTitle,
    placeLookupDisclosure,
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
