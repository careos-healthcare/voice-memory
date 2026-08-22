import 'package:archiveme_mobile/features/share/archive_share_text.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Result of a copy or share attempt — no user text leaves this enum.
enum ArchiveShareOutcome { copied, shared, fallbackCopied, failed, emptyText }

/// Shared copy/share behavior for ArchiveMe cards and export actions.
abstract class ArchiveShareActions {
  ArchiveShareActions._();

  static const String copyConfirmation = 'Share text copied';
  static const String shareFallbackMessage =
      'Could not open share sheet. Share text copied instead.';

  static bool isShareable(String? text) => ArchiveShareText.isShareable(text);

  static String normalize(String text) => ArchiveShareText.normalize(text);

  /// Popover anchor for iPad / iOS share sheets — avoids silent failures.
  static Rect sharePositionOrigin(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }
    final offset = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    if (size.width <= 0 || size.height <= 0) {
      return Rect.fromLTWH(offset.dx, offset.dy, 1, 1);
    }
    return offset & size;
  }

  static void showFeedback(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static Future<ArchiveShareOutcome> copyShareText(
    BuildContext context, {
    required String text,
    bool showConfirmation = true,
  }) async {
    final normalized = normalize(text);
    if (!isShareable(normalized)) return ArchiveShareOutcome.emptyText;
    try {
      await Clipboard.setData(ClipboardData(text: normalized));
      if (showConfirmation && context.mounted) {
        showFeedback(context, copyConfirmation);
      }
      return ArchiveShareOutcome.copied;
    } catch (_, stackTrace) {
      return ArchiveShareOutcome.failed;
    }
  }

  static Future<ArchiveShareOutcome> shareShareText(
    BuildContext context, {
    required String text,
    String? subject,
    Rect? origin,
    bool fallbackToCopy = true,
    bool showFallbackConfirmation = true,
  }) async {
    final normalized = normalize(text);
    if (!isShareable(normalized)) return ArchiveShareOutcome.emptyText;
    final shareOrigin = origin ?? sharePositionOrigin(context);
    try {
      await Share.share(
        normalized,
        subject: subject,
        sharePositionOrigin: shareOrigin,
      );
      return ArchiveShareOutcome.shared;
    } catch (_, stackTrace) {
      if (!fallbackToCopy) return ArchiveShareOutcome.failed;
      try {
        await Clipboard.setData(ClipboardData(text: normalized));
        if (showFallbackConfirmation && context.mounted) {
          showFeedback(context, shareFallbackMessage);
        }
        return ArchiveShareOutcome.fallbackCopied;
      } catch (_, stackTrace) {
        return ArchiveShareOutcome.failed;
      }
    }
  }

  /// Safe analytics — never includes share text or user content.
  static void trackShareAction({
    required String source,
    required String cardType,
    required String shareType,
    required String status,
    int? entryCount,
    String? memoryScope,
  }) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archiveShareAction,
      source: source,
      cardType: cardType,
      shareType: shareType,
      status: status,
      entryCount: entryCount,
      memoryScope: memoryScope,
    );
  }

  static String outcomeStatus(ArchiveShareOutcome outcome) {
    switch (outcome) {
      case ArchiveShareOutcome.copied:
        return 'copied';
      case ArchiveShareOutcome.shared:
        return 'shared';
      case ArchiveShareOutcome.fallbackCopied:
        return 'fallback_copied';
      case ArchiveShareOutcome.failed:
        return 'failed';
      case ArchiveShareOutcome.emptyText:
        return 'unavailable';
    }
  }
}