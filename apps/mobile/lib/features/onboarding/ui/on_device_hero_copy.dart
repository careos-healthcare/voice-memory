import 'package:archiveme_mobile/features/onboarding/ui/onboarding_v1_copy.dart';
import 'package:archiveme_mobile/features/onboarding/ui/remote_processing_consent_copy.dart';
import 'package:archiveme_mobile/features/settings/ui/on_device_architecture_copy.dart';

/// Framing for the on-device architecture hero — the last onboarding screen
/// before the customer reaches the record surface.
///
/// This class deliberately owns almost no claims. The three pillars it renders
/// are [OnDeviceArchitectureCopy] blocks verbatim, so the guarantee is not
/// worded one way in settings and another way here. What is new below is
/// framing — an eyebrow, a title, a lede, one heading, and a footnote — none of
/// which promises anything the pillars do not already say.
///
/// The pillars answer the three questions a customer actually has, and each is
/// checkable against this repository:
///
/// * *Where does processing happen?* — [pillarLocalBody] says on-device is the
///   default rather than the whole story, because `RemoteProcessingConsentStore`
///   exists to gate real uploads to `/api/transcribe`
///   (`api/retrofit/voice_memory_capture_api.dart`). It names "local databases"
///   and no engine, because the index that searches the journal still sits
///   outside it: entries are an AES-GCM envelope from `EncryptedJsonFileStore`,
///   the index is SQLCipher tables in `archiveme.db`
///   (`storage/sqlite/memory_transcript_search_repository.dart`). Different
///   engines, different platform scopes — naming either would misdescribe the
///   other.
/// * *What leaves the device, and when?* — [pillarRemoteBody] describes remote
///   work as a choice with a named off switch.
///   `RemoteProcessingConsentState.unset` is `consented: false`, so the default
///   really is off, and `RemoteProcessingConsentGate` reads that state per
///   request. [detailLink] points at `/privacy`, where
///   `RemoteProcessingDataFlow.purposeFlows` is what names the per-feature
///   audio/text flows.
/// * *Is my data used for anything else?* — [pillarAnalyticsBody] claims only
///   the boundary that `ProofAnalyticsGuard` actually enforces: a fail-closed
///   allowlist over attribute key *and* value shape, which refuses
///   `transcript`, `quote`, and any free-text value outright.
///
/// Two claims from the original brief are deliberately absent.
///
/// There is no "nothing is ever sent" or "never leaves your device" pillar: a
/// production backend is configured in `config/backend_url.txt` and audio is
/// uploaded as multipart by `data/network/http_capture_api_client.dart`.
/// Denying that the capability exists would contradict the consent step the
/// customer just answered.
///
/// There is no "your data is never used to train models" pillar either.
/// Nothing in this repository substantiates it: `features/trust/terms_screen_copy.dart`
/// contains no training-data clause, and an absence is not a commitment. The
/// repository also says nothing about what processors sit behind
/// `/api/transcribe`, so even a first-party scoping would be asserting
/// something this codebase cannot show. [pillarAnalyticsBody] replaces it with
/// the narrower secondary-use claim that is enforced in code.
///
/// Sensitive promises reach this file only through [OnDeviceArchitectureCopy],
/// which takes them from `PrivacyCopyPolicy`. Do not inline a promise here.
abstract final class OnDeviceHeroCopy {
  OnDeviceHeroCopy._();

  static const String eyebrow = 'Where your words go';

  /// The honest half of the old title. The default is a choice, not a mode.
  static const String title = 'Remote only if you ask.';

  static const String lede =
      'Three things about where your words go. Each one is a setting you can '
      'check, not a promise you have to take on faith.';

  // ——— Pillar 1: where processing happens ———

  static const String pillarLocalTitle =
      OnDeviceArchitectureCopy.architectureHeading;

  static const String pillarLocalBody =
      OnDeviceArchitectureCopy.architectureBody;

  // ——— Pillar 2: what leaves the device, and when ———

  static const String pillarRemoteTitle =
      OnDeviceArchitectureCopy.remoteHeading;

  static const String pillarRemoteBody = OnDeviceArchitectureCopy.remoteCallout;

  // ——— Pillar 3: secondary use ———

  /// The one pillar heading with no counterpart in the settings statement.
  /// "Counts, not content" is the whole of the claim — see the class doc for
  /// why it is not a training-data claim.
  static const String pillarAnalyticsTitle =
      'Analytics carry counts, not content';

  static const String pillarAnalyticsBody =
      OnDeviceArchitectureCopy.analyticsBody;

  static const List<({String title, String body})> pillars = [
    (title: pillarLocalTitle, body: pillarLocalBody),
    (title: pillarRemoteTitle, body: pillarRemoteBody),
    (title: pillarAnalyticsTitle, body: pillarAnalyticsBody),
  ];

  // ——— Live storage status ———

  /// Framing above the live status card. The card reports what this build
  /// actually does, because `SecureSqliteLockService.encryptionEnabled` is a
  /// runtime flag with an unavailable state — so nothing here asserts it.
  static const String storageStatusHeading =
      'Storage protection, as it stands now';

  static const String storageStatusBody = OnDeviceArchitectureCopy.storageBody;

  /// Reused so the hero and the consent step send customers to `/privacy`
  /// under the same words.
  static const String detailLink = RemoteProcessingConsentCopy.moreDetailLink;

  /// Reused rather than re-invented: this is the same "into the app" action the
  /// welcome page already labels.
  static const String continueCta = OnboardingV1Copy.startCta;
}
