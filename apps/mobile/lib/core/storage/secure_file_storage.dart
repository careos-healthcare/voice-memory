import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Writes an image and asks iOS to keep it encrypted while the device is locked.
abstract final class SecureFileStorage {
  SecureFileStorage._();

  static const MethodChannel channel = MethodChannel(
    'com.thoughtprint.app/file_protection',
  );

  /// Test stand-in for [setFileProtectionComplete].
  static Future<void> Function(String path)? debugProtect;

  /// Lets a host test call the iOS protection channel.
  @visibleForTesting
  static var debugForceChannel = false;

  static Future<File> writeImage({
    required String path,
    required List<int> bytes,
  }) async {
    final file = File(path);
    await file.writeAsBytes(bytes);
    await (debugProtect ?? _setFileProtectionComplete)(path);
    return file;
  }

  static Future<void> _setFileProtectionComplete(String path) async {
    if (!debugForceChannel && (kIsWeb || !Platform.isIOS)) return;
    await channel.invokeMethod<void>('setFileProtectionComplete', path);
  }
}
