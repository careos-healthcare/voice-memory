import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';

/// Compile-time gate for image evidence capture (camera / gallery).
///
/// Off until `VOICEMEMORY_ENABLE_PHOTO_ATTACHMENTS` is turned on.
abstract final class ImageEvidenceFeatureFlags {
  ImageEvidenceFeatureFlags._();

  static bool get enableImageEvidence => V1CapabilityRegistry.photoAttachments;
}
