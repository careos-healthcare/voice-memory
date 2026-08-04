import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'encrypted_image_engine.dart';
import 'media_attachment.dart';

typedef EncryptedMediaReader =
    Future<void> Function(
      MediaAttachment attachment,
      Future<void> Function(Uint8List bytes) operation,
    );

/// Owns a bounded plaintext image buffer for exactly as long as its consumer.
///
/// [dispose] evicts the associated image provider and overwrites the mutable
/// bytes. Callers must not retain [bytes] or [imageProvider] after disposal.
class EncryptedThumbnailLoader extends ChangeNotifier {
  EncryptedThumbnailLoader({
    required this.attachment,
    required this.reader,
    this.maxBytes = 4 * 1024 * 1024,
  });

  factory EncryptedThumbnailLoader.thumbnail({
    required EncryptedImageEngine engine,
    required MediaAttachment attachment,
    int maxBytes = 4 * 1024 * 1024,
  }) => EncryptedThumbnailLoader(
    attachment: attachment,
    reader: engine.withDecryptedThumbnail,
    maxBytes: maxBytes,
  );

  factory EncryptedThumbnailLoader.fullImage({
    required EncryptedImageEngine engine,
    required MediaAttachment attachment,
    int maxBytes = 24 * 1024 * 1024,
  }) => EncryptedThumbnailLoader(
    attachment: attachment,
    reader: engine.withDecryptedFullImage,
    maxBytes: maxBytes,
  );

  final MediaAttachment attachment;
  final EncryptedMediaReader reader;
  final int maxBytes;

  Uint8List? _bytes;
  MemoryImage? _imageProvider;
  Object? _error;
  bool _loading = false;
  bool _disposed = false;

  Uint8List? get bytes => _bytes;
  MemoryImage? get imageProvider => _imageProvider;
  Object? get error => _error;
  bool get isLoading => _loading;

  Future<void> load() async {
    if (_disposed || _loading || _bytes != null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await reader(attachment, (source) async {
        if (source.lengthInBytes > maxBytes) {
          throw StateError(
            'Decrypted image exceeds the $maxBytes byte presentation limit.',
          );
        }
        final owned = Uint8List.fromList(source);
        if (_disposed) {
          owned.fillRange(0, owned.length, 0);
          return;
        }
        _bytes = owned;
        _imageProvider = MemoryImage(owned);
      });
    } on Object catch (error) {
      if (!_disposed) _error = error;
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final provider = _imageProvider;
    if (provider != null) {
      PaintingBinding.instance.imageCache.evict(provider);
    }
    final clear = _bytes;
    clear?.fillRange(0, clear.length, 0);
    _bytes = null;
    _imageProvider = null;
    super.dispose();
  }
}
