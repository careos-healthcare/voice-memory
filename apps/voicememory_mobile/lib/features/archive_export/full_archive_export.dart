import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../models/journal_entry.dart';
import '../../services/privacy/audio_vault_service.dart';
import 'complete_archive_export.dart';

final class ArchiveExportCancelled implements Exception {
  const ArchiveExportCancelled();

  @override
  String toString() => 'Archive export cancelled.';
}

final class ArchiveExportCancellation {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) throw const ArchiveExportCancelled();
  }
}

final class FullArchiveExportResult {
  const FullArchiveExportResult({
    required this.archive,
    required this.manifest,
    required this.exportId,
  });

  final File archive;
  final Map<String, Object?> manifest;
  final String exportId;

  Future<void> cleanup() async {
    if (await archive.exists()) await archive.delete();
  }
}

/// Builds one portable ZIP while keeping only one decrypted recording alive.
final class FullArchiveExportBuilder {
  FullArchiveExportBuilder({
    required this.audioVault,
    required this.temporaryRoot,
    required this.appVersion,
    DateTime Function()? clock,
    String Function()? exportIdFactory,
    this.onItemAdded,
  }) : _clock = clock ?? DateTime.now,
       _exportIdFactory = exportIdFactory ?? _randomExportId;

  static const int formatVersion = 1;
  static const String _workPrefix = '.archiveme_export_work_';
  static const String archiveFileName = 'archiveme_full_archive.zip';

  final AudioVaultService audioVault;
  final Directory temporaryRoot;
  final String appVersion;
  final DateTime Function() _clock;
  final String Function() _exportIdFactory;
  final void Function(String archivePath)? onItemAdded;

  Future<FullArchiveExportResult> build({
    required ArchiveExportBundle readable,
    required Iterable<JournalEntry> entries,
    required bool audioExportConfirmed,
    ArchiveExportCancellation? cancellation,
  }) async {
    if (!audioExportConfirmed) {
      throw StateError('Audio export must be confirmed.');
    }
    final cancel = cancellation ?? ArchiveExportCancellation();
    await temporaryRoot.create(recursive: true);
    await cleanupStaleWorkDirectories();
    cancel.throwIfCancelled();

    final exportId = _safeExportId(_exportIdFactory());
    final work = Directory(p.join(temporaryRoot.path, '$_workPrefix$exportId'));
    final archive = File(
      p.join(temporaryRoot.path, 'archiveme_full_$exportId.zip'),
    );
    await work.create();

    final encoder = ZipFileEncoder();
    var encoderOpen = false;
    try {
      encoder.create(archive.path);
      encoderOpen = true;
      final items = <Map<String, Object?>>[];

      final readableFile = await _writePrivateFile(
        work,
        'readable.md',
        readable.readableDocument,
      );
      final jsonFile = await _writePrivateFile(
        work,
        'archive.json',
        readable.machineReadableJson,
      );
      await _addPayload(
        encoder,
        readableFile,
        'readable/archive.md',
        items,
        sourceRef: 'generated:readable',
        sourceDate: null,
        cancel: cancel,
      );
      await _addPayload(
        encoder,
        jsonFile,
        'data/archive.json',
        items,
        sourceRef: 'generated:machine-readable',
        sourceDate: null,
        cancel: cancel,
      );

      final ordered = entries.toList()
        ..sort((a, b) {
          final byDate = a.createdAt.toUtc().compareTo(b.createdAt.toUtc());
          return byDate != 0 ? byDate : a.id.compareTo(b.id);
        });
      for (final entry in ordered) {
        cancel.throwIfCancelled();
        await _addAudio(encoder, entry, items, cancel);
      }

      final manifest = <String, Object?>{
        'formatVersion': formatVersion,
        'exportId': exportId,
        'exportedAt': _clock().toUtc().toIso8601String(),
        'app': ArchiveExportManifest.app,
        'appVersion': appVersion,
        'archiveType': 'full',
        'pathPolicy': 'All paths are relative, sanitized, and archive-local.',
        'audioPolicy':
            'Available original audio bytes are included after confirmation.',
        'plaintextNotice':
            'After handoff, the destination you choose controls these '
            'plaintext files.',
        'items': items,
        'reports': {
          'missing': _reported(items, 'missing'),
          'corrupt': _reported(items, 'corrupt'),
          'inaccessible': _reported(items, 'inaccessible'),
          'unsupported': _reported(items, 'unsupported'),
        },
      };
      final manifestFile = await _writePrivateFile(
        work,
        'manifest.json',
        const JsonEncoder.withIndent('  ').convert(manifest),
      );
      cancel.throwIfCancelled();
      await encoder.addFile(manifestFile, 'manifest.json');
      await encoder.close();
      encoderOpen = false;
      await work.delete(recursive: true);
      return FullArchiveExportResult(
        archive: archive,
        manifest: manifest,
        exportId: exportId,
      );
    } on Object {
      if (encoderOpen) {
        try {
          await encoder.close();
        } on Object {
          // The partial archive is deleted below.
        }
      }
      await _deleteIfPresent(work);
      if (await archive.exists()) await archive.delete();
      rethrow;
    }
  }

  Future<void> cleanupStaleWorkDirectories() async {
    if (!await temporaryRoot.exists()) return;
    await for (final entity in temporaryRoot.list(followLinks: false)) {
      if (entity is! Directory ||
          !p.basename(entity.path).startsWith(_workPrefix)) {
        continue;
      }
      await _deleteIfPresent(entity);
    }
  }

  Future<void> _addAudio(
    ZipFileEncoder encoder,
    JournalEntry entry,
    List<Map<String, Object?>> items,
    ArchiveExportCancellation cancel,
  ) async {
    final vaultRef = entry.localAudioVaultRef?.trim();
    final legacyPath = entry.localAudioPath?.trim();
    final sourceRef = vaultRef != null && vaultRef.isNotEmpty
        ? _safeSourceReference(vaultRef)
        : legacyPath != null && legacyPath.isNotEmpty
        ? p.basename(legacyPath)
        : null;
    if (sourceRef == null) return;

    final basePath = 'audio/${_safeStem(entry.id)}';
    if (vaultRef == null || vaultRef.isEmpty) {
      // Legacy journal paths are untrusted host paths. Without a vault-owned
      // resolver that can prove root confinement, never open or archive them.
      items.add(
        _audioReport(
          path: '$basePath.bin',
          entry: entry,
          sourceRef: sourceRef,
          result: 'inaccessible',
        ),
      );
      return;
    }

    File encrypted;
    try {
      encrypted = await audioVault.resolveReference(vaultRef);
      if (!await encrypted.exists()) {
        items.add(
          _audioReport(
            path: '$basePath.bin',
            entry: entry,
            sourceRef: sourceRef,
            result: 'missing',
          ),
        );
        return;
      }
      if (await FileSystemEntity.type(encrypted.path, followLinks: false) ==
          FileSystemEntityType.link) {
        items.add(
          _audioReport(
            path: '$basePath.bin',
            entry: entry,
            sourceRef: sourceRef,
            result: 'inaccessible',
          ),
        );
        return;
      }
      final canonicalParent = await encrypted.parent.resolveSymbolicLinks();
      final canonicalFile = await encrypted.resolveSymbolicLinks();
      if (!p.isWithin(canonicalParent, canonicalFile)) {
        items.add(
          _audioReport(
            path: '$basePath.bin',
            entry: entry,
            sourceRef: sourceRef,
            result: 'inaccessible',
          ),
        );
        return;
      }
    } on Object catch (error) {
      items.add(
        _audioReport(
          path: '$basePath.bin',
          entry: entry,
          sourceRef: sourceRef,
          result: _classifyAudioFailure(error),
        ),
      );
      return;
    }

    try {
      await audioVault.withDecryptedFile(vaultRef, (plaintext) async {
        cancel.throwIfCancelled();
        final extension = _safeExtension(plaintext.path);
        final archivePath = '$basePath.$extension';
        final digest = await _sha256(plaintext, cancel);
        final size = await plaintext.length();
        cancel.throwIfCancelled();
        await encoder.addFile(plaintext, archivePath);
        items.add(
          _audioReport(
            path: archivePath,
            entry: entry,
            sourceRef: sourceRef,
            result: 'included',
            size: size,
            checksum: digest,
          ),
        );
        onItemAdded?.call(archivePath);
      });
    } on ArchiveExportCancelled {
      rethrow;
    } on Object catch (error) {
      items.add(
        _audioReport(
          path: '$basePath.bin',
          entry: entry,
          sourceRef: sourceRef,
          result: _classifyAudioFailure(error),
        ),
      );
    }
  }

  Future<void> _addPayload(
    ZipFileEncoder encoder,
    File file,
    String archivePath,
    List<Map<String, Object?>> items, {
    required String sourceRef,
    required DateTime? sourceDate,
    required ArchiveExportCancellation cancel,
  }) async {
    final checksum = await _sha256(file, cancel);
    final size = await file.length();
    cancel.throwIfCancelled();
    await encoder.addFile(file, archivePath);
    items.add({
      'path': archivePath,
      'sha256': checksum,
      'size': size,
      'sourceRef': sourceRef,
      'sourceDate': sourceDate?.toUtc().toIso8601String(),
      'result': 'included',
    });
    onItemAdded?.call(archivePath);
  }

  static Map<String, Object?> _audioReport({
    required String path,
    required JournalEntry entry,
    required String sourceRef,
    required String result,
    int? size,
    String? checksum,
  }) => {
    'path': path,
    'sha256': checksum,
    'size': size,
    'sourceRef': sourceRef,
    'sourceDate': entry.createdAt.toUtc().toIso8601String(),
    'result': result,
  };

  static List<Map<String, Object?>> _reported(
    List<Map<String, Object?>> items,
    String result,
  ) => items
      .where((item) => item['result'] == result)
      .map(
        (item) => {
          'path': item['path'],
          'sourceRef': item['sourceRef'],
          'sourceDate': item['sourceDate'],
          'result': item['result'],
        },
      )
      .toList(growable: false);

  static Future<File> _writePrivateFile(
    Directory directory,
    String name,
    String contents,
  ) async {
    final file = File(p.join(directory.path, name));
    await file.writeAsString(contents, flush: true);
    return file;
  }

  static Future<String> _sha256(
    File file,
    ArchiveExportCancellation cancel,
  ) async {
    final digest = await sha256
        .bind(
          file.openRead().map((chunk) {
            cancel.throwIfCancelled();
            return chunk;
          }),
        )
        .first;
    cancel.throwIfCancelled();
    return digest.toString();
  }

  static String _safeSourceReference(String value) {
    if (!value.startsWith(AudioVaultService.referencePrefix)) {
      return p.basename(value);
    }
    final name = value.substring(AudioVaultService.referencePrefix.length);
    return '${AudioVaultService.referencePrefix}${p.basename(name)}';
  }

  static String _safeStem(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^[_\-.]+|[_\-.]+$'), '');
    final prefix = cleaned.isEmpty ? 'recording' : cleaned;
    final suffix = sha256
        .convert(utf8.encode(value))
        .toString()
        .substring(0, 12);
    return '${prefix.substring(0, min(prefix.length, 48))}_$suffix';
  }

  static String _safeExtension(String path) {
    final extension = p.extension(path).replaceFirst('.', '').toLowerCase();
    return AudioVaultService.supportedExtensions.contains(extension)
        ? extension
        : 'bin';
  }

  static String _safeExportId(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    if (safe.isEmpty) throw ArgumentError('Export id must be opaque and safe.');
    return safe.substring(0, min(safe.length, 64));
  }

  static String _classifyAudioFailure(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('does not exist') || message.contains('not found')) {
      return 'missing';
    }
    if (message.contains('unsupported')) return 'unsupported';
    if (message.contains('permission') ||
        message.contains('denied') ||
        message.contains('reference is invalid')) {
      return 'inaccessible';
    }
    return 'corrupt';
  }

  static Future<void> _deleteIfPresent(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on Object {
      // Best effort on platforms where another process briefly owns a handle.
    }
  }

  static String _randomExportId() {
    final random = Random.secure();
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
