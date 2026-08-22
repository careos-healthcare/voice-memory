import 'package:archiveme_mobile/security/privacy_copy_policy.dart';

/// ArchiveMe's local-first architecture statement — the single source of truth
/// shared by the settings trust screen and the onboarding consent step.
///
/// The blocks below are contractual product copy and every claim in them is
/// checkable against this repository:
///
/// * local-first storage — `lib/storage/`, plus the on-device search index in
///   `lib/features/search/data/hybrid_search_objectbox_store.dart`, which is
///   why this copy says "databases" and names no engine;
/// * remote processing is opt-in — `RemoteProcessingConsentStore` gates the
///   uploads in `api/retrofit/voice_memory_capture_api.dart` and
///   `services/backlog_import_service.dart`, so it is described as a choice
///   rather than as something that does not exist;
/// * analytics carry no content — `ProofAnalyticsGuard` is a fail-closed
///   allowlist over key *and* value shape, matching
///   `PrivacyContract.analyticsExcludeJournalBody`;
/// * ownership — `TermsScreenCopy.contentBody`.
///
/// The sensitive promises are taken from [PrivacyCopyPolicy] rather than
/// rewritten here, so the policy stays the one place they are worded. Do not
/// reword, resplit, or re-punctuate these blocks without a copy review, and do
/// not add a claim you cannot point at code for.
abstract final class OnDeviceArchitectureCopy {
  OnDeviceArchitectureCopy._();

  static const String architectureHeading = 'On-device by default';

  static const String architectureBody =
      'On-device processing is the architecture, not a feature bolted on top. '
      'By default the audio you record, the transcripts it becomes, and the '
      'reflections you read stay here, in local databases on this device — '
      'the journal store and the index that searches it.';

  /// Points at the live encryption status instead of asserting a fixed state,
  /// because storage protection is a runtime property of the build.
  static const String storageBody =
      'How that storage is protected is reported live in privacy settings — '
      'not asserted in marketing.';

  static const String remoteHeading = 'Remote processing is opt-in';

  /// The operative qualifier — rendered as the accent callout.
  static const String remoteCallout =
      '${PrivacyCopyPolicy.nothingSentUnlessFeatureChosen} '
      'Choose transcription or sync and your audio and transcript text go to '
      'our servers for that job only; turn it off in Settings → Privacy and '
      'new moments stay on this device.';

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
