import 'package:archiveme_mobile/features/sync/application/sync_presence.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/provider_scope_probe.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Compact header chip for mesh, cloud, and conflict state.
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({required this.presence, super.key});

  final SyncPresence presence;

  @override
  Widget build(BuildContext context) {
    final colors = _colors(presence.kind);
    return Semantics(
      container: true,
      label: presence.label,
      child: Container(
        key: const Key('sync_status_badge'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          presence.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  static _BadgeColors _colors(SyncPresenceKind kind) {
    return switch (kind) {
      SyncPresenceKind.conflictDetected => const _BadgeColors(
        background: AppColors.destructiveLight,
        foreground: AppColors.error,
        border: Color(0x33DC2626),
      ),
      SyncPresenceKind.localOnly => const _BadgeColors(
        background: AppColors.surfaceAlt,
        foreground: AppColors.textMuted,
        border: AppColors.borderSubtle,
      ),
      SyncPresenceKind.synced => const _BadgeColors(
        background: AppColors.accentLight,
        foreground: AppColors.accentPrimary,
        border: Color(0x332563EB),
      ),
    };
  }
}

class SyncStatusBadgeSlot extends StatelessWidget {
  const SyncStatusBadgeSlot({super.key});

  @override
  Widget build(BuildContext context) {
    if (!hasRiverpodScope(context)) {
      return const Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: SyncStatusBadge(presence: SyncPresence()),
        ),
      );
    }
    return const Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: _LiveSyncStatusBadge(),
      ),
    );
  }
}

class _LiveSyncStatusBadge extends ConsumerWidget {
  const _LiveSyncStatusBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SyncStatusBadge(presence: ref.watch(syncStateProvider));
  }
}

class _BadgeColors {
  const _BadgeColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}
