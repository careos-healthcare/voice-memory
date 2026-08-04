import 'package:flutter/material.dart';

import 'encrypted_sync_engine.dart';

class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({
    super.key,
    required this.state,
    required this.onPressed,
  });

  final EncryptedSyncState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (state) {
      EncryptedSyncState.disabled => (Icons.cloud_off_outlined, 'Sync off'),
      EncryptedSyncState.offline => (Icons.cloud_off_outlined, 'Offline'),
      EncryptedSyncState.syncing => (Icons.cloud_sync_outlined, 'Syncing'),
      EncryptedSyncState.upToDate => (Icons.cloud_done_outlined, 'Up to date'),
      EncryptedSyncState.error => (Icons.sync_problem_outlined, 'Sync issue'),
    };
    return Semantics(
      button: true,
      label: 'Encrypted sync status: $label',
      child: ActionChip(
        key: const Key('memory-graph-sync-status-chip'),
        avatar: state == EncryptedSyncState.syncing
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Icon(icon, key: ValueKey(state), size: 18),
              ),
        label: Text(label),
        onPressed: onPressed,
      ),
    );
  }
}
