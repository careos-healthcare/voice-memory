import 'package:flutter/material.dart';

import '../../features/export/private_recap_model.dart';
import '../../features/export/private_recap_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Copy / Share / Save buttons for keeping a private copy of a recap.
class PrivateRecapActions extends StatelessWidget {
  const PrivateRecapActions({
    super.key,
    required this.recap,
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
    _notify(context, ok ? 'Copied your recap.' : 'Could not copy.');
  }

  Future<void> _share(BuildContext context) async {
    final handler = onShare ?? PrivateRecapService.shareText;
    final shared = await handler(recap);
    if (!context.mounted) return;
    if (!shared) _notify(context, 'Copied your recap.');
  }

  Future<void> _save(BuildContext context) async {
    final handler = onSave ?? ((r) => PrivateRecapService.saveText(r));
    final path = await handler(recap);
    if (!context.mounted) return;
    _notify(context, path != null ? 'Saved a copy.' : 'Could not save.');
  }

  void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
