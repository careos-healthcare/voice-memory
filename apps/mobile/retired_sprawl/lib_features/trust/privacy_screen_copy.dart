/// In-app privacy and trust copy — ArchiveMe product voice only.
library;

import 'package:archiveme_mobile/security/privacy_claim_catalogue.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';

abstract class PrivacyScreenCopy {
  PrivacyScreenCopy._();

  static const String screenTitle = 'Privacy';

  static const String intro =
      'Your recordings and reflections are personal. ArchiveMe is private by '
      'default. Audio and transcript text are sent only when you turn on '
      'remote processing for a new moment.';

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

  static const String onDeviceTitle = 'What stays on your device';
  static const String onDeviceBody =
      'Your archive entries, saved details, action items, surfacing choices, '
      'memory controls, packs, pins, and collections are stored locally by default. '
      'Archive metadata and prefs stay on this device as well.';

  static const String aiProcessingTitle = 'Cloud transcription and analysis';
  static const String aiProcessingBody =
      'When remote processing is on, ArchiveMe sends recorded audio for '
      'transcription and transcript text for reflection. When it is off, '
      'new moments are saved on this device only. Anything already saved '
      'stays exactly as it is.';

  static const String encryptedBackupTitle = 'Optional encrypted backup';
  static const String encryptedBackupBody =
      'If you sign in and enable sync, backup data is encrypted before it is '
      'uploaded, using a key held on this device. The server stores that '
      'backup as ciphertext. Sync is optional.';

  static const String doesNotDoTitle = 'What ArchiveMe does not do';
  static const String doesNotDoBody =
      'ArchiveMe does not sell your reflections. ArchiveMe does not include '
      'recording text in analytics. ArchiveMe does not turn every entry into '
      'personal memory by default. ArchiveMe is not therapy, medical advice, '
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

  /// Names the companies that receive content, and what each one gets.
  ///
  /// This used to read "ArchiveMe may use trusted processing providers […]
  /// Provider names may appear in the full privacy policy where required",
  /// which named nobody and pointed at a document to name them later. It has
  /// always had a home: `PrivacyScreen` renders it in the
  /// `privacy_processing_providers` tile, under a visible heading, collapsed
  /// until tapped. That placement is kept — a reader who wants to know who
  /// sees their recordings goes to Privacy and finds the heading, and a reader
  /// who does not is not handed a list of vendors mid-scroll.
  ///
  /// Each sentence is checkable against a request the backend actually makes:
  ///
  /// * audio to OpenAI — `apps/api/app/api/transcribe/route.ts` posts the
  ///   recorded file to `whisper-1`;
  /// * transcript to OpenAI — `apps/api/app/api/analyze/route.ts` posts the
  ///   transcript to `gpt-4o-mini`;
  /// * live audio to Google — `packages/shared/lib/live-audio/upstream-url.ts`
  ///   streams to Gemini, behind `VOICEMEMORY_ENABLE_LIVE_CONVERSATION` and
  ///   `V1CapabilityRegistry.liveVoice`, both off, which is why the sentence
  ///   says "where that feature is available" rather than describing it as
  ///   something the reader has;
  /// * sync — `encrypted_sync_service.dart` uploads ciphertext.
  ///
  /// Google embedding of fact-ledger text is deliberately *not* listed.
  /// `packages/shared/lib/gemini-embeddings.ts` does send transcript text to
  /// `text-embedding-004`, but only from `/api/ledger/bulk-import`, and this
  /// app never calls it: `bulkImportJson` and `bulkImportMultipart` exist in
  /// the generated Retrofit client with no call site in `lib/`. Naming a
  /// processor that receives nothing is the same failure as hiding one that
  /// does — it makes the list unverifiable. Add the sentence when a caller
  /// lands.
  ///
  /// Anthropic is deliberately absent. Nothing in this repository calls it,
  /// and listing vendors you do not use to say you do not use them only
  /// raises the question about the ones you do.
  static const String processingProvidersTitle = 'Processing providers';
  static const String processingProvidersBody =
      'Remote processing is off until you turn it on, and these companies '
      'receive nothing before then. If you turn it on: OpenAI receives a '
      "moment's recorded audio to transcribe it, then the transcript text — "
      'along with structured details of the earlier moments it is compared '
      'against — to draft a reflection. Google receives streamed audio during '
      'a live conversation, where that feature is available. Encrypted backup '
      'is separate: sync uploads ciphertext, so the server holds backup data '
      'it cannot read.';

  static const String fullPolicyLink = 'Full privacy policy online';

  static const String remoteProcessingSectionTitle = 'Remote processing';
  static const String remoteProcessingSwitchLabel =
      'Send new moments for transcription and reflection';
  static const String remoteProcessingSwitchBodyOn =
      'On — a new moment\'s audio and transcript may be sent to transcribe '
      'and compare it against what you\'ve said before. Turn this off any '
      'time; anything already saved stays exactly as it is.';
  static const String remoteProcessingSwitchBodyOff =
      'Off — new moments are saved on this device only. Nothing is sent '
      'for transcription or reflection until you turn this on.';
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
    whereWordsGoTitle,
    whereWordsGoBody,
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
