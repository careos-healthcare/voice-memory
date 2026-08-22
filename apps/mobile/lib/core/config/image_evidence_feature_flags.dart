import 'package:archiveme_mobile/core/config/v1_capability_registry.dart' show V1CapabilityRegistry;
import 'package:archiveme_mobile/features/recording/recording_dependencies.dart' show V1CapabilityRegistry;

/// Compile-time gate for image evidence capture (camera / gallery).
///
/// Default off — matches [V1CapabilityRegistry.cameraAndPhotos].
/// Enable locally with: `--dart-define=VOICEMEMORY_ENABLE_IMAGE_EVIDENCE=true`
abstract final class ImageEvidenceFeatureFlags {
  ImageEvidenceFeatureFlags._();

  static const bool _compileTimeDefault = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_IMAGE_EVIDENCE',
  );

  static bool get enableImageEvidence => _compileTimeDefault;
}