import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:image_picker/image_picker.dart';

/// Opens the system photo picker and returns local file paths.
///
/// On iOS this uses PHPicker, which hands back the chosen photos without
/// requesting access to the whole photo library. The picker stays closed
/// until [V1CapabilityRegistry.photoAttachments] is on.
Future<List<String>> pickEntryImages() async {
  if (!V1CapabilityRegistry.photoAttachments) return const [];
  final files = await ImagePicker().pickMultiImage(
    maxWidth: 2048,
    maxHeight: 2048,
    imageQuality: 85,
  );
  return [
    for (final file in files)
      if (file.path.trim().isNotEmpty) file.path.trim(),
  ];
}
