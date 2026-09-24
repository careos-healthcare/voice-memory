import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A photo that already lives on the device.
class RecentMediaAsset {
  const RecentMediaAsset({
    required this.localPath,
    required this.mimeType,
    this.filename,
  });

  final String localPath;
  final String mimeType;
  final String? filename;
}

/// Reads the newest gallery item without uploading it.
abstract class RecentGallerySource {
  const RecentGallerySource();

  Future<RecentMediaAsset?> latestAsset();
}

/// Gallery access is intentionally unavailable when photos are not a V1
/// capability. Callers get null instead of a platform exception.
class UnavailableGallerySource extends RecentGallerySource {
  const UnavailableGallerySource();

  @override
  Future<RecentMediaAsset?> latestAsset() async => null;
}

/// Fetches the most recent on-device photo for a one-tap import.
class MediaPickerService {
  MediaPickerService({RecentGallerySource? source})
    : _source = source ?? const UnavailableGallerySource();

  final RecentGallerySource _source;

  Future<RecentMediaAsset?> fetchMostRecentAsset() => _source.latestAsset();
}

final mediaPickerServiceProvider = Provider<MediaPickerService>(
  (ref) => MediaPickerService(),
);
