import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Subtle Local / Synced mark on an entry row.
class EntrySyncIndicator extends StatelessWidget {
  const EntrySyncIndicator({required this.status, super.key});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      SyncStatus.synced => 'Synced',
      SyncStatus.conflict => 'Conflict',
      _ => 'Local',
    };
    final color = switch (status) {
      SyncStatus.synced => AppColors.accentPrimary,
      SyncStatus.conflict => AppColors.error,
      _ => AppColors.textMuted,
    };
    return Text(
      label,
      key: const Key('entry_sync_indicator'),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
    );
  }
}
