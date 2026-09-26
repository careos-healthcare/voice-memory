import 'dart:io';

import 'package:archiveme_mobile/features/export/private_recap_model.dart';
import 'package:archiveme_mobile/features/share/archive_share_actions.dart';
import 'package:archiveme_mobile/features/share/archive_share_text.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Copy / Share / Save buttons for keeping a private copy of a recap.
class PrivateRecapActions extends StatelessWidget {
  const PrivateRecapActions({
    required this.recap,
    super.key,
    this.onCopy,
    this.onShare,
    this.onSave,
    this.allowSave,
  });

  final PrivateRecap recap;

  /// Overrides for testing. Default to [PrivateRecapService].
  final Future<bool> Function(PrivateRecap)? onCopy;
  final Future<bool> Function(PrivateRecap)? onShare;
  final Future<String?> Function(PrivateRecap)? onSave;

  /// Whether to show the Save button. Defaults to the platform capability.
  final bool? allowSave;

  bool get _saveEnabled => allowSave ?? PrivateRecapService.canSave;

  Future<void> _copy(BuildContext context) async {
    final handler = onCopy ?? PrivateRecapService.copyToClipboard;
    final ok = await handler(recap);
    if (!context.mounted) return;
    _notify(
      context,
      ok ? ArchiveShareActions.copyConfirmation : 'Could not copy.',
    );
  }

  Future<void> _share(BuildContext context) async {
    final handler =
        onShare ??
        ((r) => PrivateRecapService.shareText(
          r,
          sharePositionOrigin: ArchiveShareActions.sharePositionOrigin(context),
        ));
    final shared = await handler(recap);
    if (!context.mounted) return;
    if (!shared) {
      _notify(context, ArchiveShareActions.shareFallbackMessage);
    }
  }

  Future<void> _save(BuildContext context) async {
    final handler = onSave ?? (PrivateRecapService.saveText);
    final path = await handler(recap);
    if (!context.mounted) return;
    _notify(context, path != null ? 'Saved a copy.' : 'Could not save.');
  }

  void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        _button(
          context,
          icon: Icons.copy_rounded,
          label: 'Copy',
          onPressed: () => _copy(context),
        ),
        _button(
          context,
          icon: Icons.ios_share,
          label: 'Share',
          onPressed: () => _share(context),
        ),
        if (_saveEnabled)
          _button(
            context,
            icon: Icons.download_rounded,
            label: 'Save',
            onPressed: () => _save(context),
          ),
      ],
    );
  }

  Widget _button(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accentPrimary,
        side: BorderSide(color: AppColors.accentPrimary.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}

/// Copies, shares, or saves a [PrivateRecap] as plain text the user can keep.
///
/// The export screen no longer offers this. Research screens that still show
/// a private copy call these helpers directly.
abstract class PrivateRecapService {
  PrivateRecapService._();

  static Future<bool> copyToClipboard(PrivateRecap recap) async {
    final text = ArchiveShareText.normalize(recap.plainText);
    if (!ArchiveShareText.isShareable(text)) return false;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (_, stackTrace) {
      return false;
    }
  }

  static Future<bool> shareText(
    PrivateRecap recap, {
    Rect? sharePositionOrigin,
  }) async {
    final text = ArchiveShareText.normalize(recap.plainText);
    if (!ArchiveShareText.isShareable(text)) return false;
    try {
      await Share.share(
        text,
        sharePositionOrigin:
            sharePositionOrigin ?? const Rect.fromLTWH(0, 0, 1, 1),
      );
      return true;
    } catch (_, stackTrace) {
      await copyToClipboard(recap);
      return false;
    }
  }

  static bool get canSave => !kIsWeb;

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
    } catch (_, stackTrace) {
      return null;
    }
  }
}
