import 'dart:io';
import 'dart:typed_data';

/// A file a peer can offer. [assetId] is stable across devices.
class MeshAssetManifestEntry {
  const MeshAssetManifestEntry({
    required this.assetId,
    required this.fileName,
    required this.byteLength,
  });

  final String assetId;
  final String fileName;
  final int byteLength;
}

/// One slice of a raw audio file or image attachment.
class MeshAssetChunk {
  const MeshAssetChunk({
    required this.assetId,
    required this.offset,
    required this.bytes,
  });

  final String assetId;
  final int offset;
  final Uint8List bytes;
}

/// Pulls audio and image files a peer has and this device does not.
class MeshAssetReconciler {
  const MeshAssetReconciler({this.chunkSize = 8 * 1024});

  final int chunkSize;

  static const audioExtensions = <String>{'.m4a', '.wav'};
  static const imageExtensions = <String>{
    '.png',
    '.jpg',
    '.jpeg',
    '.heic',
    '.webp',
    '.gif',
  };

  static bool isSyncableAsset(String fileName) {
    return _extension(fileName) != null && safeFileName(fileName) != null;
  }

  /// A single path segment with an audio or image extension.
  static String? safeFileName(String fileName) {
    final name = fileName.trim();
    if (name.isEmpty) return null;
    if (name.contains('/') || name.contains(r'\')) return null;
    if (name.contains('..')) return null;
    if (_extension(name) == null) return null;
    return name;
  }

  /// Remote files this device does not already store.
  List<MeshAssetManifestEntry> missing({
    required Iterable<MeshAssetManifestEntry> remote,
    required Set<String> localAssetIds,
  }) {
    final needed = <MeshAssetManifestEntry>[];
    for (final entry in remote) {
      if (localAssetIds.contains(entry.assetId)) continue;
      if (safeFileName(entry.fileName) == null) continue;
      needed.add(entry);
    }
    return needed;
  }

  /// Reads [file] in [chunkSize] slices without loading a second full copy
  /// beyond the current window.
  Stream<MeshAssetChunk> streamFile(
    File file, {
    required String assetId,
  }) async* {
    final handle = await file.open();
    try {
      var offset = 0;
      while (true) {
        final bytes = await handle.read(chunkSize);
        if (bytes.isEmpty) break;
        yield MeshAssetChunk(assetId: assetId, offset: offset, bytes: bytes);
        offset += bytes.length;
        if (bytes.length < chunkSize) break;
      }
    } finally {
      await handle.close();
    }
  }

  Stream<MeshAssetChunk> streamBytes({
    required String assetId,
    required Uint8List bytes,
  }) async* {
    if (bytes.isEmpty) return;
    var offset = 0;
    while (offset < bytes.length) {
      final end = offset + chunkSize > bytes.length
          ? bytes.length
          : offset + chunkSize;
      yield MeshAssetChunk(
        assetId: assetId,
        offset: offset,
        bytes: Uint8List.sublistView(bytes, offset, end),
      );
      offset = end;
    }
  }

  /// Writes each missing asset by consuming [open] chunk streams.
  Future<List<File>> pullMissing({
    required Directory destination,
    required Iterable<MeshAssetManifestEntry> remote,
    required Set<String> localAssetIds,
    required Stream<MeshAssetChunk> Function(MeshAssetManifestEntry entry) open,
  }) async {
    if (!destination.existsSync()) {
      destination.createSync(recursive: true);
    }
    final written = <File>[];
    for (final entry in missing(
      remote: remote,
      localAssetIds: localAssetIds,
    )) {
      final name = safeFileName(entry.fileName);
      if (name == null) continue;
      final chunks = await open(entry).toList();
      final bytes = assemble(chunks);
      final file = File('${destination.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      written.add(file);
    }
    return written;
  }

  Uint8List assemble(List<MeshAssetChunk> chunks) {
    if (chunks.isEmpty) return Uint8List(0);
    final ordered = [...chunks]..sort((a, b) => a.offset.compareTo(b.offset));
    final builder = BytesBuilder(copy: false);
    var cursor = 0;
    for (final part in ordered) {
      if (part.offset != cursor) {
        throw StateError('Gap in asset ${part.assetId} at $cursor');
      }
      builder.add(part.bytes);
      cursor += part.bytes.length;
    }
    return builder.takeBytes();
  }

  static String? _extension(String fileName) {
    final lower = fileName.toLowerCase();
    for (final extension in {...audioExtensions, ...imageExtensions}) {
      if (lower.endsWith(extension)) return extension;
    }
    return null;
  }
}
