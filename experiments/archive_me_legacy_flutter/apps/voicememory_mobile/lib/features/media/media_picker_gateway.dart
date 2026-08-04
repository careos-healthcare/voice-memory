import 'package:image_picker/image_picker.dart';

import '../../storage/app_storage_paths.dart';

enum MediaPickSource { camera, gallery }

/// Whether the app is responsible for deleting the picked source file.
enum MediaSourceCleanupOwnership {
  /// Camera captures are app-owned temporary files.
  appOwnedTemporary,

  /// Gallery paths refer to user-owned originals and must never be changed.
  externalOriginal,
}

class PickedMediaSource {
  const PickedMediaSource({required this.path, required this.cleanupOwnership});

  final String path;
  final MediaSourceCleanupOwnership cleanupOwnership;
}

abstract interface class MediaPickerGateway {
  Future<PickedMediaSource?> pickImage(MediaPickSource source);
}

class ImagePickerMediaGateway implements MediaPickerGateway {
  ImagePickerMediaGateway({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedMediaSource?> pickImage(MediaPickSource source) async {
    final picked = await _picker.pickImage(
      source: source == MediaPickSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (picked == null) return null;
    var appOwnedTemporary = source == MediaPickSource.camera;
    if (!appOwnedTemporary) {
      try {
        final temporary = await AppStoragePaths.temporaryDirectory();
        final root = temporary.absolute.path;
        final selected = picked.path;
        appOwnedTemporary =
            selected == root ||
            selected.startsWith(root.endsWith('/') ? root : '$root/');
      } on Object {
        // Unknown gallery paths are treated as user-owned and never deleted.
      }
    }
    return PickedMediaSource(
      path: picked.path,
      cleanupOwnership: appOwnedTemporary
          ? MediaSourceCleanupOwnership.appOwnedTemporary
          : MediaSourceCleanupOwnership.externalOriginal,
    );
  }
}
