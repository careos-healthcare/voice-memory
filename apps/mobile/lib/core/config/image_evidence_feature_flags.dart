import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';

/// Compile-time gate for attaching a photo from the camera or photo library.
abstract final class ImageEvidenceFeatureFlags {
  ImageEvidenceFeatureFlags._();

  static bool get enableImageEvidence => V1CapabilityRegistry.photoAttachments;
}
