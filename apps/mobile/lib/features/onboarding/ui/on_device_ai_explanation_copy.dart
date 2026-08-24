import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_copy.dart';
import 'package:archiveme_mobile/features/settings/ui/on_device_architecture_copy.dart';
import 'package:archiveme_mobile/security/privacy_claim_catalogue.dart';

/// Named copy surface for the on-device AI explanation step.
///
/// This file exists so the privacy-copy gate discovers the explanation as its
/// own `*_copy.dart`. It does not invent claims. Every user-visible string is
/// an alias of [OnDeviceHeroCopy], [OnDeviceArchitectureCopy], or
/// [PrivacyClaimCatalogue], which already take sensitive promises from
/// `PrivacyCopyPolicy`.
///
/// The sentence "Your data stays on your phone. Our AI runs entirely on your
/// device, meaning your personal information never goes to the cloud." is
/// deliberately absent. Remote transcription, analysis, Firebase Analytics
/// (behind consent), and a production backend all exist. On-device processing
/// is a user-selectable mode, not the only architecture.
abstract final class OnDeviceAiExplanationCopy {
  OnDeviceAiExplanationCopy._();

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

  static const List<String> bullets = [
    journalDefault,
    onDeviceAvailable,
    remoteIsOptIn,
    remoteScopedToJob,
    remoteOffSwitch,
  ];
}
