import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../activation/activation_tracker.dart';
import '../share/archive_share_text.dart';
import 'pattern_share_recap_model.dart';

/// Copies or shares a [PatternShareRecap] as plain text the user can keep.
abstract class PatternShareService {
  PatternShareService._();

  /// Copies the recap's plain text to the clipboard.
  static Future<bool> copyToClipboard(PatternShareRecap recap) async {
    final text = ArchiveShareText.normalize(recap.plainText);
    if (!ArchiveShareText.isShareable(text)) {
      ActivationTracker.trackPatternShareFailed();
      return false;
    }
    try {
      await Clipboard.setData(ClipboardData(text: text));
      ActivationTracker.trackPatternShareCopied();
      return true;
    } catch (_) {
      ActivationTracker.trackPatternShareFailed();
      return false;
    }
  }

  /// Opens the native share sheet.
  ///
  /// Returns true when the native sheet was invoked. When native share is
  /// unavailable (e.g. some desktops/tests) it falls back to copying the recap
  /// to the clipboard and returns false so callers can confirm the copy.
  static Future<bool> shareText(
    PatternShareRecap recap, {
    Rect? sharePositionOrigin,
  }) async {
    final text = ArchiveShareText.normalize(recap.plainText);
    if (!ArchiveShareText.isShareable(text)) {
      ActivationTracker.trackPatternShareFailed();
      return false;
    }
    try {
      await Share.share(
        text,
        sharePositionOrigin:
            sharePositionOrigin ?? const Rect.fromLTWH(0, 0, 1, 1),
      );
      ActivationTracker.trackPatternShareOpened();
      return true;
    } catch (_) {
      ActivationTracker.trackPatternShareFailed();
      await copyToClipboard(recap);
      return false;
    }
  }
}
