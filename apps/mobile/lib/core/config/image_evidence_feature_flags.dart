import 'package:archiveme_mobile/core/config/v1_capability_registry.dart' show V1CapabilityRegistry;
import 'package:archiveme_mobile/features/recording/recording_dependencies.dart' show V1CapabilityRegistry;

/// Compile-time gate for image evidence capture (camera / gallery).
///
/// On for this beta. Turn off with:
/// `--dart-define=VOICEMEMORY_ENABLE_IMAGE_EVIDENCE=false`
abstract final class ImageEvidenceFeatureFlags {
  ImageEvidenceFeatureFlags._();

  static const bool _compileTimeDefault = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_IMAGE_EVIDENCE',
    defaultValue: true,
  );

  static bool get enableImageEvidence => _compileTimeDefault;
}