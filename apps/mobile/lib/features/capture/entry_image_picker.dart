import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/media/services/image_processor_service.dart';
import 'package:image_picker/image_picker.dart';

/// Opens the camera or photo library and stores a compressed journal photo.
///
/// Stays closed until [V1CapabilityRegistry.photoAttachments] is on.
Future<List<String>> pickEntryImages({
  ImageSource source = ImageSource.gallery,
  String? entryId,
  bool? keepGps,
  Future<List<XFile>> Function(ImageSource source)? pick,
  ImageProcessorService? processor,
}) async {
  if (!V1CapabilityRegistry.photoAttachments) return const [];
  final chosen = await (pick ?? _pick)(source);
  final stored = <String>[];
  final writer = processor ?? ImageProcessorService();
  final retainGps = keepGps ?? V1CapabilityRegistry.location;
  for (final file in chosen) {
    final path = file.path.trim();
    if (path.isEmpty) continue;
    final media = await writer.processAndStoreImage(
      File(path),
      entryId: entryId,
      keepGps: retainGps,
    );
    stored.add(media.highResPath);
  }
  return stored;
}

Future<List<XFile>> _pick(ImageSource source) async {
  final picker = ImagePicker();
  if (source == ImageSource.camera) {
    final shot = await picker.pickImage(source: ImageSource.camera);
    if (shot == null) return const [];
    return [shot];
  }
  return picker.pickMultiImage();
}
