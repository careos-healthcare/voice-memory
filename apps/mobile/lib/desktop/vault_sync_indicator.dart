import 'dart:async';

import 'package:archiveme_mobile/desktop/vault_sync_status.dart';
import 'package:archiveme_mobile/features/sync/application/sync_status_provider.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/provider_scope_probe.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sidebar and app-bar reading of vault encryption, peers, and last sync.
class VaultSyncStatusIndicator extends StatelessWidget {
  const VaultSyncStatusIndicator({
    required this.status,
    super.key,
    this.compact = false,
  });

  final VaultSyncStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary,
      height: 1.3,
    );
    return Semantics(
      container: true,
      label:
          'Vault. ${status.encryptionLabel}. ${status.peerLabel}. '
          '${status.lastSyncedLabel}',
      child: Padding(
        key: const Key('vault_sync_status'),
        padding: EdgeInsets.fromLTRB(compact ? 8 : 12, 8, compact ? 8 : 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Vault',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(status.encryptionLabel, style: style),
            Text(status.peerLabel, style: style),
            Text(status.lastSyncedLabel, style: style),
          ],
        ),
      ),
    );
  }
}

/// Live indicator when Riverpod is mounted; otherwise a local fallback.
class VaultSyncStatusSlot extends StatelessWidget {
  const VaultSyncStatusSlot({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!hasRiverpodScope(context)) {
      return VaultSyncStatusIndicator(
        status: VaultSyncStatus.localFallback,
        compact: compact,
      );
    }
    return _LiveVaultSyncStatus(compact: compact);
  }
}

class _LiveVaultSyncStatus extends ConsumerStatefulWidget {
  const _LiveVaultSyncStatus({required this.compact});

  final bool compact;

  @override
  ConsumerState<_LiveVaultSyncStatus> createState() =>
      _LiveVaultSyncStatusState();
}

class _LiveVaultSyncStatusState extends ConsumerState<_LiveVaultSyncStatus> {
  DateTime? _persistedSync;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPersistedSync());
  }

  Future<void> _loadPersistedSync() async {
    if (!AppServices.isInitialized) return;
    final raw = await AppServices.instance.prefs.lastSyncAt;
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    if (!mounted) return;
    setState(() => _persistedSync = parsed);
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncStatusProvider);
    final completed = sync.sync.lastCompletedAt;
    final persisted = _persistedSync;
    final last = switch ((completed, persisted)) {
      (null, final saved) => saved,
      (final live, null) => live,
      (final live?, final saved?) => live.isAfter(saved) ? live : saved,
    };
    return VaultSyncStatusIndicator(
      compact: widget.compact,
      status: VaultSyncStatus.fromApp(sync: sync, lastSyncedAt: last),
    );
  }
}
