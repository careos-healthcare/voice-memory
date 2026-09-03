import 'package:archiveme_mobile/security/privacy_claim_catalogue.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';

/// ArchiveMe's local-first architecture statement — the single source of truth
/// shared by the settings trust screen and the onboarding consent step.
///
/// The blocks below are contractual product copy and every claim in them is
/// checkable against this repository:
///
/// * local-first storage — `lib/storage/`. Still two stores, still two
///   engines, which is why this copy says "databases" and names none of them:
///   journal entries are an AES-GCM envelope written by `JournalStore` through
///   `EncryptedJsonFileStore`, while the index that searches them is SQLCipher
///   tables in `archiveme.db` (`MemoryTranscriptSearchRepository`, holding both
///   the FTS rows and the `memory_transcript_embeddings` BLOBs). Naming one
///   engine would misdescribe the other, and they are protected by different
///   mechanisms with different platform scopes — see
///   [PrivacyCopyPolicy.encryptionBaselineDetail]. Storage is the whole of the
///   claim: no model ArchiveMe ships runs here, because the tree carries no
///   model binaries and `pubspec.yaml` bundles no model assets, so the copy no
///   longer says the transcripts and reflections are *produced* on this
///   device;
/// * transcript production is split by platform — iOS reaches Apple's
///   `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true` through
///   `NativeSpeechTranscription`, while Android refuses that channel
///   (`NativeSpeechTranscription.blockedPlatforms`) and has to take the server
///   path. "Where the system supports it" is the platform split stated without
///   naming a platform, because the answer changes per OS release and this
///   copy cannot;
/// * remote processing is opt-in — `RemoteProcessingConsentStore` gates the
///   uploads in `api/retrofit/voice_memory_capture_api.dart` and
///   `services/backlog_import_service.dart`, so it is described as a choice
///   rather than as something that does not exist;
/// * analytics carry no content — `ProofAnalyticsGuard` is a fail-closed
///   allowlist over key *and* value shape, matching
///   `PrivacyCopyPolicy.analyticsExcludeJournalBody`;
/// * ownership — `TermsScreenCopy.contentBody`.
///
/// The sensitive promises are taken from [PrivacyCopyPolicy] rather than
/// rewritten here, so the policy stays the one place they are worded. Do not
/// reword, resplit, or re-punctuate these blocks without a copy review, and do
/// not add a claim you cannot point at code for.
abstract final class OnDeviceArchitectureCopy {
  OnDeviceArchitectureCopy._();

  static const String architectureHeading =
      PrivacyClaimCatalogue.whatYouSaveStaysHereHeading;

  static const String architectureBody =
      'Local-first storage is the architecture, not a bolted-on feature. By '
      'default your recordings, transcripts, and reflections stay in local '
      'databases here. A transcript is produced here where the system '
      'supports it, on our servers when you allow that.';

  /// Points at the live encryption status instead of asserting a fixed state,
  /// because storage protection is a runtime property of the build. "Them" is
  /// what [architectureBody] has just finished listing.
  static const String storageBody =
      PrivacyClaimCatalogue.storageProtectionReportedLive;

  static const String remoteHeading = 'Remote processing is opt-in';

  /// The operative qualifier — rendered as the accent callout.
  static const String remoteCallout =
      '${PrivacyClaimCatalogue.remoteProcessingIsAChoice} '
      '${PrivacyClaimCatalogue.remoteProcessingScopedToJob} '
      '${PrivacyClaimCatalogue.remoteProcessingOffSwitch}';

  static const String analyticsBody =
      'Usage analytics carry counts and states, not your words. Journal text '
      'and transcripts are refused at that boundary rather than cleaned up '
      'afterwards.';

  static const String ownershipHeading = 'Ownership';

  static const String ownershipBody =
      'What is on this device is yours. The terms say the same thing: you '
      'keep ownership of what you record.';

  static const String ownershipControls = PrivacyCopyPolicy.exportDeleteAnytime;

  /// The complete statement in reading order.
  ///
  /// Headings are layout only, so this concatenation is what the user actually
  /// reads top to bottom. Tests assert it against the approved wording to catch
  /// any drift in the blocks above.
  static const String fullStatement =
      '$architectureBody $storageBody $remoteCallout $analyticsBody '
      '$ownershipBody $ownershipControls';
}
