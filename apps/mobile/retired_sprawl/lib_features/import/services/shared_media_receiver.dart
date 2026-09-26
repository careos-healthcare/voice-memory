import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A shared audio file whose recording date came from the file itself.
class SharedAudioIntake {
  const SharedAudioIntake({required this.path, required this.recordedAt});

  final String path;
  final DateTime recordedAt;
}

/// Listens for an audio file the share extension left for the main app.
abstract final class SharedMediaReceiver {
  SharedMediaReceiver._();

  static const MethodChannel channel = MethodChannel(
    'archive_me/voice_memo_import',
  );

  static const allowedExtensions = {'.m4a', '.mp3', '.wav'};

  static bool accepts(String path) {
    final lower = path.toLowerCase();
    return allowedExtensions.any(lower.endsWith);
  }

  /// Creation time stored on the file. Missing metadata stays missing.
  static Future<DateTime?> originalRecordingDate(
    File file, {
    Future<String?> Function(String path)? readCreationDate,
  }) async {
    final raw = readCreationDate != null
        ? await readCreationDate(file.path)
        : await _nativeCreationDate(file.path);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
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
    final recorded = fromPayload is String
        ? DateTime.tryParse(fromPayload)?.toUtc()
        : await originalRecordingDate(file, readCreationDate: readCreationDate);
    if (recorded == null) return null;
    return SharedAudioIntake(path: path, recordedAt: recorded);
  }

  static Future<String?> _nativeCreationDate(String path) async {
    if (kIsWeb || !Platform.isIOS) return null;
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

  static Future<Map<Object?, Object?>?> _take() async {
    if (kIsWeb || !Platform.isIOS) return null;
    try {
      return await channel.invokeMethod<Map<Object?, Object?>>('takePending');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
