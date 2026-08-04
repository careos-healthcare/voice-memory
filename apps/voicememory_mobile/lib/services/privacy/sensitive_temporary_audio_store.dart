import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../../storage/app_storage_paths.dart';

enum TemporaryAudioState { pending, recoverable }

final class TemporaryAudioItem {
  const TemporaryAudioItem({
    required this.id,
    required this.ownerId,
    required this.file,
    required this.createdAt,
    required this.bytes,
    required this.state,
  });

  final String id;
  final String ownerId;
  final File file;
  final DateTime createdAt;
  final int bytes;
  final TemporaryAudioState state;
}

abstract interface class SensitiveAudioDirectoryPlatform {
  Future<Directory> resolve();
}

final class NativeSensitiveAudioDirectoryPlatform
    implements SensitiveAudioDirectoryPlatform {
  const NativeSensitiveAudioDirectoryPlatform();

  static const channel = MethodChannel(
    'archive_me/sensitive_temporary_audio_store',
  );

  @override
  Future<Directory> resolve() async {
    final path = await channel.invokeMethod<String>('protectedDirectory');
    if (path == null || path.trim().isEmpty) {
      throw const FileSystemException(
        'Protected temporary audio directory unavailable.',
      );
    }
    return Directory(path);
  }
}

typedef SensitiveAudioDirectoryResolver = Future<Directory> Function();

/// Bounded plaintext audio recovery storage.
///
/// The platform directory is private and excluded from backup. Files remain
/// plaintext only while capture/recovery requires them and are never uploaded
/// by this store. Deletion includes a best-effort zero pass, but flash storage
/// and copy-on-write filesystems do not provide a physical overwrite guarantee.
final class SensitiveTemporaryAudioStore {
  SensitiveTemporaryAudioStore({
    SensitiveAudioDirectoryPlatform? platform,
    SensitiveAudioDirectoryResolver? directory,
    List<SensitiveAudioDirectoryResolver>? legacyDirectories,
    DateTime Function()? clock,
    Random? random,
    this.maxAge = const Duration(hours: 24),
    this.maxItems = 20,
    this.maxBytes = 512 * 1024 * 1024,
  }) : _platform = platform ?? const NativeSensitiveAudioDirectoryPlatform(),
       // Public named parameters cannot expose private field names.
       // ignore: prefer_initializing_formals
       _directory = directory,
       _legacyDirectories = legacyDirectories ?? _defaultLegacyDirectories,
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  static final SensitiveTemporaryAudioStore production =
      SensitiveTemporaryAudioStore();

  static const Set<String> supportedExtensions = {
    'aac',
    'caf',
    'm4a',
    'mp4',
    'ogg',
    'wav',
  };
  static const String _migrationMarker = '.legacy_vm_rec_migrated_v1';

  final SensitiveAudioDirectoryPlatform _platform;
  final SensitiveAudioDirectoryResolver? _directory;
  final List<SensitiveAudioDirectoryResolver> _legacyDirectories;
  final DateTime Function() _clock;
  final Random _random;
  final Duration maxAge;
  final int maxItems;
  final int maxBytes;

  Future<File> create({
    required String ownerId,
    required String extension,
  }) async {
    _validateOwner(ownerId);
    final normalizedExtension = _normalizeExtension(extension);
    await migrateLegacyOnce(knownOwnerId: ownerId);
    await purge();
    final root = await _root();
    final id = _opaqueId();
    final file = File(p.join(root.path, '$id.$normalizedExtension'));
    await file.create(exclusive: true);
    await _writeMetadata(
      file,
      ownerId: ownerId,
      createdAt: _clock().toUtc(),
      state: TemporaryAudioState.pending,
    );
    await _enforceLimits(protectedPath: file.path);
    return file;
  }

  Future<T> controlledOpen<T>({
    required File file,
    required String ownerId,
    required Future<T> Function(RandomAccessFile handle) operation,
    FileMode mode = FileMode.read,
  }) async {
    final metadata = await _requireOwned(file, ownerId);
    if (_isExpired(metadata.createdAt)) {
      await delete(file: file, ownerId: ownerId);
      throw const FileSystemException('Temporary audio has expired.');
    }
    final handle = await file.open(mode: mode);
    try {
      return await operation(handle);
    } finally {
      await handle.close();
    }
  }

  Future<void> markPending({required File file, required String ownerId}) =>
      _setState(file, ownerId, TemporaryAudioState.pending);

  Future<void> markRecoverable({
    required File file,
    required String ownerId,
  }) async {
    await _setState(file, ownerId, TemporaryAudioState.recoverable);
    await _enforceLimits(protectedPath: file.path);
  }

  /// Completes the plaintext lifecycle after durable encryption succeeds.
  Future<void> markEncryptionComplete({
    required File file,
    required String ownerId,
  }) => delete(file: file, ownerId: ownerId);

  Future<void> delete({required File file, required String ownerId}) async {
    await _requireOwned(file, ownerId);
    await _bestEffortDelete(file);
    await _deleteMetadata(file);
  }

  Future<List<TemporaryAudioItem>> list({
    required String ownerId,
    bool recoverableOnly = false,
  }) async {
    _validateOwner(ownerId);
    await purge();
    final all = await _readAll();
    return all
        .where(
          (item) =>
              item.ownerId == ownerId &&
              (!recoverableOnly ||
                  item.state == TemporaryAudioState.recoverable),
        )
        .toList(growable: false);
  }

  Future<void> purge() async {
    final root = await _root();
    if (!await root.exists()) return;
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! File) {
        if (entity is Directory) await entity.delete(recursive: true);
        continue;
      }
      final name = p.basename(entity.path);
      if (name == _migrationMarker || name.endsWith('.meta')) continue;
      final metadata = await _readMetadata(entity);
      if (metadata == null ||
          _isExpired(metadata.createdAt) ||
          !supportedExtensions.contains(_extension(entity.path))) {
        await _bestEffortDelete(entity);
        await _deleteMetadata(entity);
      }
    }
    await _purgeOrphanMetadata();
    await _enforceLimits();
  }

  Future<void> purgePending() async {
    for (final item in await _readAll()) {
      if (item.state == TemporaryAudioState.pending) {
        await _bestEffortDelete(item.file);
        await _deleteMetadata(item.file);
      }
    }
  }

  /// Moves legacy `vm_rec_*` files without copying and preserves file time.
  Future<void> migrateLegacyOnce({String? knownOwnerId}) async {
    if (knownOwnerId != null) _validateOwner(knownOwnerId);
    final root = await _root();
    final marker = File(p.join(root.path, _migrationMarker));
    if (await marker.exists()) return;
    var retryRequired = false;
    for (final resolver in _legacyDirectories) {
      Directory legacy;
      try {
        legacy = await resolver();
      } on Object {
        continue;
      }
      if (!await legacy.exists() || p.equals(legacy.path, root.path)) continue;
      await for (final entity in legacy.list(followLinks: false)) {
        if (entity is! File || !_isLegacyRecording(entity.path)) continue;
        final stat = await entity.stat();
        final createdAt = _legacyCreatedAt(entity.path, stat.modified);
        final extension = _extension(entity.path);
        final expired = _clock().toUtc().difference(createdAt) >= maxAge;
        if (expired ||
            stat.size <= 0 ||
            !supportedExtensions.contains(extension)) {
          await _bestEffortDelete(entity);
          continue;
        }
        final target = File(p.join(root.path, '${_opaqueId()}.$extension'));
        try {
          final moved = await entity.rename(target.path);
          await _writeMetadata(
            moved,
            ownerId: knownOwnerId ?? 'legacy-recovery',
            createdAt: createdAt,
            state: TemporaryAudioState.recoverable,
          );
        } on FileSystemException {
          // Never create a second plaintext copy across filesystems.
          retryRequired = true;
        }
      }
    }
    if (!retryRequired) {
      await marker.writeAsString('1', flush: true);
    }
    await purge();
  }

  Future<void> handleLifecycle(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        await migrateLegacyOnce();
        await purge();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        await purge();
      case AppLifecycleState.detached:
        await purgePending();
        await purge();
    }
  }

  Future<void> _setState(
    File file,
    String ownerId,
    TemporaryAudioState state,
  ) async {
    final metadata = await _requireOwned(file, ownerId);
    await _writeMetadata(
      file,
      ownerId: ownerId,
      createdAt: metadata.createdAt,
      state: state,
    );
  }

  Future<_TemporaryAudioMetadata> _requireOwned(
    File file,
    String ownerId,
  ) async {
    _validateOwner(ownerId);
    final root = await _root();
    if (!p.isWithin(root.path, file.path) || !await file.exists()) {
      throw const FileSystemException('Temporary audio is unavailable.');
    }
    final metadata = await _readMetadata(file);
    if (metadata == null || metadata.ownerId != ownerId) {
      throw const FileSystemException('Temporary audio owner mismatch.');
    }
    return metadata;
  }

  Future<List<TemporaryAudioItem>> _readAll() async {
    final root = await _root();
    final items = <TemporaryAudioItem>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! File || p.basename(entity.path).endsWith('.meta')) {
        continue;
      }
      if (p.basename(entity.path) == _migrationMarker) continue;
      final metadata = await _readMetadata(entity);
      if (metadata == null) continue;
      items.add(
        TemporaryAudioItem(
          id: p.basenameWithoutExtension(entity.path),
          ownerId: metadata.ownerId,
          file: entity,
          createdAt: metadata.createdAt,
          bytes: await entity.length(),
          state: metadata.state,
        ),
      );
    }
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  Future<void> _enforceLimits({String? protectedPath}) async {
    final items = await _readAll();
    var count = items.length;
    var bytes = items.fold<int>(0, (total, item) => total + item.bytes);
    for (final item in items) {
      if (count <= maxItems && bytes <= maxBytes) break;
      if (item.file.path == protectedPath) continue;
      await _bestEffortDelete(item.file);
      await _deleteMetadata(item.file);
      count--;
      bytes -= item.bytes;
    }
    if (count > maxItems || bytes > maxBytes) {
      throw const FileSystemException(
        'Temporary audio storage limit exceeded.',
      );
    }
  }

  Future<_TemporaryAudioMetadata?> _readMetadata(File file) async {
    try {
      final decoded =
          jsonDecode(await _metadataFile(file).readAsString())
              as Map<String, dynamic>;
      final createdAt = DateTime.parse(decoded['createdAt'] as String).toUtc();
      final ownerId = decoded['ownerId'] as String;
      final state = TemporaryAudioState.values.byName(
        decoded['state'] as String,
      );
      if (ownerId.isEmpty) return null;
      return _TemporaryAudioMetadata(
        ownerId: ownerId,
        createdAt: createdAt,
        state: state,
      );
    } on Object {
      return null;
    }
  }

  Future<void> _writeMetadata(
    File file, {
    required String ownerId,
    required DateTime createdAt,
    required TemporaryAudioState state,
  }) async {
    await _metadataFile(file).writeAsString(
      jsonEncode({
        'version': 1,
        'ownerId': ownerId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'state': state.name,
      }),
      flush: true,
    );
  }

  Future<void> _purgeOrphanMetadata() async {
    final root = await _root();
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.meta')) continue;
      final audioPath = entity.path.substring(0, entity.path.length - 5);
      if (!await File(audioPath).exists()) await entity.delete();
    }
  }

  Future<void> _deleteMetadata(File file) async {
    final metadata = _metadataFile(file);
    if (await metadata.exists()) await metadata.delete();
  }

  Future<Directory> _root() async {
    final root = _directory == null
        ? await _platform.resolve()
        : await _directory();
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  bool _isExpired(DateTime createdAt) =>
      _clock().toUtc().difference(createdAt.toUtc()) >= maxAge;

  String _opaqueId() {
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  static File _metadataFile(File file) => File('${file.path}.meta');

  static String _extension(String path) =>
      p.extension(path).replaceFirst('.', '').toLowerCase();

  static String _normalizeExtension(String extension) {
    final normalized = extension.replaceFirst('.', '').toLowerCase();
    if (!supportedExtensions.contains(normalized)) {
      throw ArgumentError.value(extension, 'extension', 'Unsupported audio');
    }
    return normalized;
  }

  static bool _isLegacyRecording(String path) {
    final name = p.basename(path);
    return name.startsWith('vm_rec_');
  }

  static DateTime _legacyCreatedAt(String path, DateTime fallback) {
    final timestamp = RegExp(
      r'(?<!\d)(\d{13})(?!\d)',
    ).firstMatch(p.basename(path))?.group(1);
    if (timestamp != null) {
      final milliseconds = int.tryParse(timestamp);
      if (milliseconds != null) {
        final parsed = DateTime.fromMillisecondsSinceEpoch(
          milliseconds,
          isUtc: true,
        );
        if (parsed.year >= 2000 && parsed.year <= 2100) return parsed;
      }
    }
    return fallback.toUtc();
  }

  static void _validateOwner(String ownerId) {
    if (ownerId.isEmpty || ownerId.length > 128) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Invalid owner');
    }
  }

  static Future<void> _bestEffortDelete(File file) async {
    if (!await file.exists()) return;
    RandomAccessFile? handle;
    try {
      final length = await file.length();
      handle = await file.open(mode: FileMode.write);
      const chunkSize = 1024 * 1024;
      final zeros = List<int>.filled(min(chunkSize, max(1, length)), 0);
      var remaining = length;
      while (remaining > 0) {
        final count = min(remaining, zeros.length);
        await handle.writeFrom(zeros, 0, count);
        remaining -= count;
      }
      await handle.flush();
      await handle.truncate(0);
    } on Object {
      // Deletion remains authoritative when overwrite is unsupported.
    } finally {
      await handle?.close();
      if (await file.exists()) await file.delete();
    }
  }

  static final List<SensitiveAudioDirectoryResolver> _defaultLegacyDirectories =
      [
        AppStoragePaths.temporaryDirectory,
        () async => Directory.systemTemp,
        () async {
          final support = await AppStoragePaths.applicationSupportDirectory();
          return Directory(p.join(support.path, 'temporary_recordings'));
        },
        () async => AppStoragePaths.applicationDocumentsDirectory(),
      ];
}

final class _TemporaryAudioMetadata {
  const _TemporaryAudioMetadata({
    required this.ownerId,
    required this.createdAt,
    required this.state,
  });

  final String ownerId;
  final DateTime createdAt;
  final TemporaryAudioState state;
}
