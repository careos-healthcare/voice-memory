import 'package:flutter/material.dart';

import '../../../../services/capture_pipeline_service.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../domain/models/offline_vault_manifest.dart';

Future<void> showOfflineVaultRecoveryModal({
  required BuildContext context,
  required OfflineVaultManifest manifest,
  required Future<CapturePipelineResult> Function() onRecover,
  required Future<void> Function() onDiscard,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _OfflineVaultRecoveryDialog(
        manifest: manifest,
        onRecover: onRecover,
        onDiscard: onDiscard,
      );
    },
  );
}

class _OfflineVaultRecoveryDialog extends StatefulWidget {
  const _OfflineVaultRecoveryDialog({
    required this.manifest,
    required this.onRecover,
    required this.onDiscard,
  });

  final OfflineVaultManifest manifest;
  final Future<CapturePipelineResult> Function() onRecover;
  final Future<void> Function() onDiscard;

  @override
  State<_OfflineVaultRecoveryDialog> createState() =>
      _OfflineVaultRecoveryDialogState();
}

class _OfflineVaultRecoveryDialogState extends State<_OfflineVaultRecoveryDialog> {
  var _busy = false;
  String? _error;

  Future<void> _recover() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onRecover();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Recovery upload failed. You can retry when back online.';
      });
    }
  }

  Future<void> _discard() async {
    setState(() => _busy = true);
    try {
      await widget.onDiscard();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (widget.manifest.durationSeconds / 60).ceil().clamp(1, 999);
    return AlertDialog(
      backgroundColor: AppColors.backgroundSecondary,
      title: const Text('Recover interrupted recording'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'We saved an encrypted voice recording from your last live session '
            '(about $minutes min). Upload it now to finish your journal entry.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _discard,
          child: const Text('Discard'),
        ),
        FilledButton(
          onPressed: _busy ? null : _recover,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Recover now'),
        ),
      ],
    );
  }
}
