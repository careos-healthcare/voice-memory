import 'dart:io';

import 'package:path/path.dart' as p;

import 'complete_archive_export.dart';

/// Owns one opaque, root-confined directory for a readable export handoff.
final class ReadableArchiveTempFiles {
  ReadableArchiveTempFiles._({
    required this.directory,
    required this.readable,
    required this.machineReadable,
  });

  static const String directoryPrefix = '.archiveme_readable_';

  final Directory directory;
  final File readable;
  final File machineReadable;

  static Future<ReadableArchiveTempFiles> create(
    Directory temporaryRoot,
  ) async {
    await temporaryRoot.create(recursive: true);
    await _cleanupStale(temporaryRoot);
    final directory = await temporaryRoot.createTemp(directoryPrefix);
    try {
      final canonicalRoot = await temporaryRoot.resolveSymbolicLinks();
      final canonicalDirectory = await directory.resolveSymbolicLinks();
      if (!p.isWithin(canonicalRoot, canonicalDirectory)) {
        throw FileSystemException(
          'Readable export directory escaped its private temporary root.',
        );
      }
      return ReadableArchiveTempFiles._(
        directory: directory,
        readable: File(
          p.join(directory.path, ArchiveExportBundle.readableFileName),
        ),
        machineReadable: File(
          p.join(directory.path, ArchiveExportBundle.machineReadableFileName),
        ),
      );
    } on Object {
      if (await directory.exists()) await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> write(ArchiveExportBundle bundle) async {
    if (await FileSystemEntity.type(readable.path, followLinks: false) !=
            FileSystemEntityType.notFound ||
        await FileSystemEntity.type(machineReadable.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
      throw const FileSystemException('Readable export targets already exist.');
    }
    await readable.writeAsString(bundle.readableDocument, flush: true);
    await machineReadable.writeAsString(
      bundle.machineReadableJson,
      flush: true,
    );
  }

  Future<void> cleanup() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  static Future<void> _cleanupStale(Directory temporaryRoot) async {
    await for (final entity in temporaryRoot.list(followLinks: false)) {
      if (entity is! Directory ||
          !p.basename(entity.path).startsWith(directoryPrefix)) {
        continue;
      }
      await entity.delete(recursive: true);
    }
  }
}
