import 'package:archiveme_mobile/security/privacy_copy_policy.dart';

/// Muted trust indicators for archive and settings footers.
///
/// The encryption chip used to read "Encrypted at Rest" with a semantic label
/// claiming "local journal storage and the SQLite vault are encrypted on this
/// device". Both were false as written: SQLCipher is gated on
/// `Platform.isIOS || Platform.isAndroid` by
/// `SqliteDatabaseInitializer.encryptionEnabled`, so the database half is off
/// on desktop builds, and preferences and archive metadata are plain JSON on
/// every platform. The wording now comes from [PrivacyCopyPolicy] so the scope
/// is stated in the one place these promises are worded.
///
/// The processing chip had the same shape of problem and a worse claim. It
/// rendered "Processed On-Device" unconditionally, with the semantic label
/// "Local language models run on this device first." No model ArchiveMe ships
/// runs here — the tree carries no model binaries and `pubspec.yaml` bundles
/// no model assets, so every encoder falls back to a deterministic stand-in.
/// What is genuinely local is storage and search, so that is what the default
/// chip claims. The processing variant is reserved for an entry that recorded
/// `JournalProofData.processingUsedOnnx == true`, which is the one signal in
/// the model that means a bundled model actually ran.
abstract final class TrustStatusFooterCopy {
  TrustStatusFooterCopy._();

  static const String encryptedAtRest = PrivacyCopyPolicy.encryptedAtRestScoped;

  /// Chip shown when an entry recorded that a bundled model produced it.
  static const processedOnDevice = 'Processed here — not sent';

  /// The default chip. Storage and search are local on every platform.
  static const storedOnDevice = 'Stored on this phone';

  /// Carries the platform scope and the exclusions the chip has no room for.
  static const encryptedSemanticLabel =
      '$encryptedAtRest. ${PrivacyCopyPolicy.encryptionBaselineDetail}';

  /// Only reachable from an entry whose proof flags record a bundled model.
  static const onDeviceSemanticLabel =
      'Processed here. This entry was not sent for a remote read.';

  /// Says what is local without implying the device produces the text.
  ///
  /// Transcription is split by platform rather than absent: iOS reaches
  /// Apple's on-device `SFSpeechRecognizer` through `NativeSpeechTranscription`
  /// while Android is on that class's `blockedPlatforms` list and takes the
  /// server path, so this names the condition instead of promising either
  /// outcome.
  static const storedOnDeviceSemanticLabel =
      'Stored on-device. Your entries are stored and searched on this device. '
      'Transcription runs here where the system provides a speech recogniser, '
      'and on our servers when you allow that.';

  static String labelFor({required bool processingUsedOnDevice}) =>
      processingUsedOnDevice ? processedOnDevice : storedOnDevice;

  static String semanticLabelFor({required bool processingUsedOnDevice}) =>
      processingUsedOnDevice
      ? onDeviceSemanticLabel
      : storedOnDeviceSemanticLabel;
}
