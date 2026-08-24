import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_copy.dart';
import 'package:archiveme_mobile/features/settings/ui/on_device_architecture_copy.dart';
import 'package:archiveme_mobile/security/privacy_claim_catalogue.dart';

/// Named copy surface for the on-device AI disclosure step.
///
/// This file exists so the privacy-copy gate discovers the disclosure as its
/// own `*_copy.dart`. Sensitive promises are aliases of [OnDeviceHeroCopy],
/// [OnDeviceArchitectureCopy], or [PrivacyClaimCatalogue]. The heading and
/// button labels are not custody claims.
///
/// The sentence "Your data stays on your phone. Our AI runs entirely on your
/// device, meaning your personal information never goes to the cloud." is
/// deliberately absent. Remote transcription, analysis, Firebase Analytics
/// (behind consent), and a production backend all exist. On-device processing
/// is a user-selectable mode, not the only architecture.
abstract final class OnDeviceAiDisclosureCopy {
  OnDeviceAiDisclosureCopy._();

  static const String title = OnDeviceHeroCopy.title;

  static const String lede = OnDeviceHeroCopy.lede;

  /// Journal storage, as the catalogue already states it.
  static const String journalDefault = PrivacyClaimCatalogue.momentsStayLocal;

  /// Local-first default, including the platform split for transcripts.
  static const String onDeviceAvailable =
      OnDeviceArchitectureCopy.architectureBody;

  /// Remote work is a named choice, not an absence of servers.
  static const String remoteIsOptIn =
      PrivacyClaimCatalogue.remoteProcessingIsAChoice;

  static const String remoteScopedToJob =
      PrivacyClaimCatalogue.remoteProcessingScopedToJob;

  static const String remoteOffSwitch =
      PrivacyClaimCatalogue.remoteProcessingOffSwitch;

  static const String continueCta = OnDeviceHeroCopy.continueCta;

  /// Visual heading on the disclosure screen. A priority statement, not a
  /// custody claim — it does not say where data goes.
  static const String heading = 'Your Privacy Is Priority #1';

  /// Body slot on the disclosure screen. Replaces the requested false
  /// sentence "Our AI processes everything directly on this device. Your data
  /// never leaves your phone."
  static const String body =
      '${OnDeviceHeroCopy.title} ${PrivacyClaimCatalogue.remoteProcessingIsAChoice}';

  /// Acknowledges the disclosure and continues onboarding. Does not grant
  /// remote-processing consent — that decision is the previous step.
  static const String understandCta = 'I Understand, Let’s Continue';

  /// Returns to the previous onboarding step. Does not decline remote consent.
  static const String cancelCta = 'Cancel';

  static const List<String> bullets = [
    journalDefault,
    onDeviceAvailable,
    remoteIsOptIn,
    remoteScopedToJob,
    remoteOffSwitch,
  ];
}

/// Previous name for [OnDeviceAiDisclosureCopy].
typedef OnDeviceAiExplanationCopy = OnDeviceAiDisclosureCopy;
