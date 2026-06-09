import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'private_recap_model.dart';

/// Copies, shares, or saves a [PrivateRecap] as plain text the user can keep.
///
/// Everything is private and local: there is no upload, no account, no public
/// surface.
abstract final class PrivateRecapService {
  PrivateRecapService._();

  /// Copies the recap's plain text to the clipboard.
  static Future<bool> copyToClipboard(PrivateRecap recap) async {
    try {
      await Clipboard.setData(ClipboardData(text: recap.plainText));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Opens the native share sheet.
  ///
  /// Returns true when the native sheet was invoked. When native share is
  /// unavailable (e.g. some desktops/tests) it falls back to copying the recap
  /// and returns false so callers can confirm the copy instead.
  static Future<bool> shareText(PrivateRecap recap) async {
    try {
      await Share.share(recap.plainText);
      return true;
    } catch (_) {
      await copyToClipboard(recap);
      return false;
    }
  }

  /// Whether saving a text file is supported on this platform. Web cannot write
  /// arbitrary files, so saving is disabled there.
  static bool get canSave => !kIsWeb;

  /// Saves the recap as a plain-text file and returns its path, or null when
  /// saving is unsupported or fails. Writes into [directory] when provided
  /// (used by tests); otherwise the system temporary directory.
  static Future<String?> saveText(
    PrivateRecap recap, {
    Directory? directory,
  }) async {
    if (!canSave) return null;
    try {
      final dir = directory ?? Directory.systemTemp;
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/archiveme_recap_$stamp.txt');
      await file.writeAsString(recap.plainText);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
