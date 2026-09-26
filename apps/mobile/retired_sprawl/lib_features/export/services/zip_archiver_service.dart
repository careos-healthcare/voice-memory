import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Media copied into a portable archive, keyed by the name inside the zip.
class PackedMedia {
  const PackedMedia({
    required this.audioByName,
    required this.photosByName,
  });

  final Map<String, List<int>> audioByName;
  final Map<String, List<int>> photosByName;
}

/// Builds a zip with `audio/` and `photos/`, using file names instead of
/// device paths.
abstract final class ZipArchiverService {
  ZipArchiverService._();

  static const audioDirectory = 'audio';
  static const photosDirectory = 'photos';

  /// Portable JSON fields. Device paths are never included.
  static Map<String, Object> portableMediaFields({
    String? audioPath,
    Iterable<String> images = const [],
  }) {
    final audio = relativeAudio(audioPath);
    final photos = relativePhotos(images);
    return {
      if (audio != null) 'audio_file': audio,
      if (photos.isNotEmpty) 'images': photos,
    };
  }

  static String? relativeAudio(String? path) {
    final name = audioFileName(path);
    if (name == null) return null;
    return '$audioDirectory/$name';
  }

  static List<String> relativePhotos(Iterable<String> paths) {
    return [
      for (final path in paths)
        if (photoFileName(path) case final name?) '$photosDirectory/$name',
    ];
  }

  /// Basename of an `.m4a` recording, or null when there is nothing to copy.
  static String? audioFileName(String? path) {
    final name = _baseName(path);
    if (name == null || !name.toLowerCase().endsWith('.m4a')) return null;
    return name;
  }

  /// Basename of a full-size `.jpg`. Previews and other types are skipped.
  static String? photoFileName(String? path) {
    final name = _baseName(path);
    if (name == null) return null;
    final lower = name.toLowerCase();
    if (lower.contains('_thumb.')) return null;
    if (lower.endsWith('.jpeg')) {
      return '${name.substring(0, name.length - 5)}.jpg';
    }
    if (!lower.endsWith('.jpg')) return null;
    return name;
  }

  static List<String> photoFileNames(Iterable<String> paths) {
    return [
      for (final path in paths)
        if (photoFileName(path) case final name?) name,
    ];
  }

  /// Copies each entry's recording and full-size photos when the files exist.
  static Future<PackedMedia> packEntries(Iterable<JournalEntry> entries) async {
    final audio = <String, List<int>>{};
    final photos = <String, List<int>>{};
    for (final entry in entries) {
      final audioName = audioFileName(entry.audioUrl);
      final audioPath = entry.audioUrl;
      if (audioName != null && audioPath != null) {
        final bytes = await _readIfExists(audioPath);
        if (bytes != null) audio[audioName] = bytes;
      }
      for (final image in entry.images) {
        final name = photoFileName(image);
        if (name == null) continue;
        final bytes = await _readIfExists(image);
        if (bytes != null) photos[name] = bytes;
      }
    }
    return PackedMedia(audioByName: audio, photosByName: photos);
  }

  static Uint8List encode({
    Map<String, List<int>> documents = const {},
    Map<String, List<int>> audio = const {},
    Map<String, List<int>> photos = const {},
  }) {
    final archive = Archive();
    for (final item in documents.entries) {
      archive.addFile(ArchiveFile(item.key, item.value.length, item.value));
    }
    for (final item in audio.entries) {
      final name = _under(audioDirectory, item.key);
      archive.addFile(ArchiveFile(name, item.value.length, item.value));
    }
    for (final item in photos.entries) {
      final name = _under(photosDirectory, item.key);
      archive.addFile(ArchiveFile(name, item.value.length, item.value));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static String _under(String folder, String name) {
    final trimmed = name.trim();
    if (trimmed.startsWith('$folder/')) return trimmed;
    final base = trimmed.split(RegExp(r'[/\\]')).last;
    return '$folder/$base';
  }

  static String? _baseName(String? path) {
    if (path == null) return null;
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;
    final name = trimmed.split(RegExp(r'[/\\]')).last;
    if (name.isEmpty || name == '.' || name == '..') return null;
    return name;
  }

  static Future<List<int>?> _readIfExists(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }
}
