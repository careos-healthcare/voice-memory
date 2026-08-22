import 'dart:io';

import 'package:archiveme_mobile/storage/app_storage_paths.dart';
import 'package:path/path.dart' as p;

typedef DocumentsDirectoryResolver = Future<Directory> Function();

/// Persists completed `record` captures under the app documents directory.
class LocalAudioStorageService {
  LocalAudioStorageService({
    DocumentsDirectoryResolver? resolveDocumentsDirectory,
  }) : _resolveDocumentsDirectory =
           resolveDocumentsDirectory ??
           AppStoragePaths.applicationDocumentsDirectory;

  static const pendingAudioDirectoryName = 'pending_audio';

  final DocumentsDirectoryResolver _resolveDocumentsDirectory;

  Future<Directory> pendingAudioDirectory() async {
    final documents = await _resolveDocumentsDirectory();
    final dir = Directory(
      p.join(documents.path, pendingAudioDirectoryName),
    );
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Copies [sourceFile] into documents storage and returns the durable path.
  Future<String> saveRecordingFile({
    required File sourceFile,
    required String recordingId,
  }) async {
    if (!sourceFile.existsSync()) {
      throw StateError('Recording file does not exist: ${sourceFile.path}');
    }

    final directory = await pendingAudioDirectory();
    final extension = p.extension(sourceFile.path);
    final normalizedExtension = extension.isEmpty ? '.m4a' : extension;
    final destinationPath = p.join(
      directory.path,
      '$recordingId$normalizedExtension',
    );

    if (p.normalize(sourceFile.path) == p.normalize(destinationPath)) {
      return destinationPath;
    }

    await sourceFile.copy(destinationPath);
    await _deleteIfTemporary(sourceFile);
    return destinationPath;
  }

  Future<void> deleteRecordingFile(String filePath) async {
    final file = File(filePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<void> _deleteIfTemporary(File sourceFile) async {
    final normalized = p.normalize(sourceFile.path);
    if (!normalized.contains('tmp') &&
        !normalized.contains('temp') &&
        !normalized.contains('Temporary')) {
      return;
    }
    try {
      if (sourceFile.existsSync()) {
        await sourceFile.delete();
      }
    } on Object {
      // Best-effort cleanup of the transient recorder path.
    }
  }
}
