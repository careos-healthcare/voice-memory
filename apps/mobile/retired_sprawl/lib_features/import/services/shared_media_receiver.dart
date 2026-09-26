import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A shared audio file whose recording date came from the file itself.
class SharedAudioIntake {
  const SharedAudioIntake({
    required this.path,
    required this.recordedAt,
    this.name,
  });

  final String path;
  final DateTime recordedAt;
  final String? name;
}

/// Listens for an audio file the share extension left for the main app.
abstract final class SharedMediaReceiver {
  SharedMediaReceiver._();

  static const MethodChannel channel = MethodChannel(
    'archive_me/voice_memo_import',
  );

  static const allowedExtensions = {'.m4a', '.mp3', '.wav', '.ogg'};

  static bool accepts(String path) {
    final lower = path.toLowerCase();
    return allowedExtensions.any(lower.endsWith);
  }

  /// AVAsset creation date when the native side finds one, otherwise the
  /// file's modification time. Never the moment of import.
  static DateTime? preferRecordingDate({
    String? metadataIso,
    DateTime? fileModified,
  }) {
    final parsed = metadataIso == null || metadataIso.trim().isEmpty
        ? null
        : DateTime.tryParse(metadataIso.trim())?.toUtc();
    return parsed ?? fileModified?.toUtc();
  }

  static Future<DateTime?> originalRecordingDate(
    File file, {
    Future<String?> Function(String path)? readCreationDate,
  }) async {
    final raw = readCreationDate != null
        ? await readCreationDate(file.path)
        : await _nativeCreationDate(file.path);
    DateTime? modified;
    try {
      modified = await file.lastModified();
    } on FileSystemException {
      modified = null;
    }
    return preferRecordingDate(metadataIso: raw, fileModified: modified);
  }

  static Future<SharedAudioIntake?> takePending({
    Map<Object?, Object?>? pending,
    Future<String?> Function(String path)? readCreationDate,
  }) async {
    final payload = pending ?? await _take();
    if (payload == null) return null;
    final path = payload['path'];
    if (path is! String || !accepts(path)) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    final fromPayload = payload['createdAt'];
    final recorded =
        (fromPayload is String
            ? DateTime.tryParse(fromPayload)?.toUtc()
            : null) ??
        await originalRecordingDate(file, readCreationDate: readCreationDate);
    if (recorded == null) return null;
    final name = payload['name'];
    return SharedAudioIntake(
      path: path,
      recordedAt: recorded,
      name: name is String && name.trim().isNotEmpty ? name.trim() : null,
    );
  }

  static Future<List<SharedAudioIntake>> takeAll({
    List<Map<Object?, Object?>>? pending,
    Future<String?> Function(String path)? readCreationDate,
  }) async {
    final rows = pending ?? await _takeQueue();
    if (rows == null || rows.isEmpty) {
      final one = await takePending(readCreationDate: readCreationDate);
      return one == null ? const [] : [one];
    }
    final intakes = <SharedAudioIntake>[];
    for (final row in rows) {
      final intake = await takePending(
        pending: row,
        readCreationDate: readCreationDate,
      );
      if (intake != null) intakes.add(intake);
    }
    return intakes;
  }

  static Future<String?> _nativeCreationDate(String path) async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return null;
    try {
      return await channel.invokeMethod<String>('creationDate', {
        'path': path,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<List<Map<Object?, Object?>>?> _takeQueue() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return null;
    try {
      final rows = await channel.invokeMethod<List<Object?>>('takeQueue');
      if (rows == null) return null;
      return [
        for (final row in rows)
          if (row is Map) Map<Object?, Object?>.from(row),
      ];
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<Map<Object?, Object?>?> _take() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return null;
    try {
      return await channel.invokeMethod<Map<Object?, Object?>>('takePending');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
