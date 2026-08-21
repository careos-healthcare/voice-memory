import 'package:archiveme_mobile/features/sync/presentation/sync_status_snapshot.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Full-width banner showing live sync progress, offline state, and pending uploads.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({
    required this.status,
    super.key,
  });

  final SyncStatusSnapshot status;

  @override
  Widget build(BuildContext context) {
    if (!status.showBanner) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colors = _BannerColors.forKind(status.visualKind);

    return Semantics(
      liveRegion: true,
      label: status.bannerMessage,
      child: Material(
        color: colors.background,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: _BannerIcon(
                      kind: status.visualKind,
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      status.bannerMessage,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.foreground,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (status.pendingUploadCount > 0)
                    ExcludeSemantics(
                      child: _PendingCountChip(
                        count: status.pendingUploadCount,
                        color: colors.foreground,
                      ),
                    ),
                ],
              ),
              if (status.showProgress && status.progressFraction != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: status.progressFraction,
                    minHeight: 4,
                    backgroundColor: colors.foreground.withValues(alpha: 0.18),
                    color: colors.foreground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerIcon extends StatelessWidget {
  const _BannerIcon({
    required this.kind,
    required this.color,
  });

  final SyncStatusVisualKind kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      SyncStatusVisualKind.syncing => SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: color,
        ),
      ),
      SyncStatusVisualKind.error => Icon(Icons.error_outline, size: 18, color: color),
      SyncStatusVisualKind.offline => Icon(Icons.cloud_off_outlined, size: 18, color: color),
      SyncStatusVisualKind.waiting => Icon(Icons.schedule, size: 18, color: color),
      SyncStatusVisualKind.pending => Icon(Icons.cloud_upload_outlined, size: 18, color: color),
      SyncStatusVisualKind.idle => Icon(Icons.cloud_done_outlined, size: 18, color: color),
    };
  }
}

class _PendingCountChip extends StatelessWidget {
  const _PendingCountChip({
    required this.count,
    required this.color,
  });

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        count.toString(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

final class _BannerColors {
  const _BannerColors({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;

  static _BannerColors forKind(SyncStatusVisualKind kind) {
    return switch (kind) {
      SyncStatusVisualKind.error => const _BannerColors(
        background: AppColors.destructiveLight,
        foreground: AppColors.error,
      ),
      SyncStatusVisualKind.offline => const _BannerColors(
        background: AppColors.surfaceAlt,
        foreground: AppColors.warning,
      ),
      SyncStatusVisualKind.syncing => const _BannerColors(
        background: AppColors.accentLight,
        foreground: AppColors.accentPrimary,
      ),
      SyncStatusVisualKind.waiting => const _BannerColors(
        background: AppColors.surfaceAlt,
        foreground: AppColors.textMuted,
      ),
      SyncStatusVisualKind.pending => const _BannerColors(
        background: AppColors.surfaceAlt,
        foreground: AppColors.accentSecondary,
      ),
      SyncStatusVisualKind.idle => const _BannerColors(
        background: AppColors.surfaceAlt,
        foreground: AppColors.textMuted,
      ),
    };
  }
}
