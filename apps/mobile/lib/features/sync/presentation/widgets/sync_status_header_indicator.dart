import 'package:archiveme_mobile/features/sync/presentation/sync_status_snapshot.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Compact header indicator for sync progress and pending upload counts.
class SyncStatusHeaderIndicator extends StatelessWidget {
  const SyncStatusHeaderIndicator({
    required this.status,
    super.key,
  });

  final SyncStatusSnapshot status;

  @override
  Widget build(BuildContext context) {
    if (!status.showHeaderIndicator) {
      return const SizedBox.shrink();
    }

    final colors = _IndicatorColors.forKind(status.visualKind);

    return Semantics(
      button: false,
      label: status.headerSemanticsLabel,
      child: Tooltip(
        message: status.bannerMessage,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: _IndicatorIcon(
                  kind: status.visualKind,
                  color: colors.foreground,
                ),
              ),
              if (status.headerBadgeLabel != null) ...[
                const SizedBox(width: 6),
                Text(
                  status.headerBadgeLabel!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.w700,
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

class _IndicatorIcon extends StatelessWidget {
  const _IndicatorIcon({
    required this.kind,
    required this.color,
  });

  final SyncStatusVisualKind kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      SyncStatusVisualKind.syncing => SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      ),
      SyncStatusVisualKind.error => Icon(Icons.error_outline, size: 16, color: color),
      SyncStatusVisualKind.offline => Icon(Icons.cloud_off_outlined, size: 16, color: color),
      SyncStatusVisualKind.waiting => Icon(Icons.schedule, size: 16, color: color),
      SyncStatusVisualKind.pending => Icon(Icons.cloud_upload_outlined, size: 16, color: color),
      SyncStatusVisualKind.idle => Icon(Icons.cloud_done_outlined, size: 16, color: color),
    };
  }
}

final class _IndicatorColors {
  const _IndicatorColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;

  static _IndicatorColors forKind(SyncStatusVisualKind kind) {
    return switch (kind) {
      SyncStatusVisualKind.error => const _IndicatorColors(
        background: AppColors.destructiveLight,
        foreground: AppColors.error,
        border: Color(0x33DC2626),
      ),
      SyncStatusVisualKind.offline => const _IndicatorColors(
        background: AppColors.surfaceAlt,
        foreground: AppColors.warning,
        border: AppColors.borderSubtle,
      ),
      SyncStatusVisualKind.syncing => const _IndicatorColors(
        background: AppColors.accentLight,
        foreground: AppColors.accentPrimary,
        border: Color(0x332563EB),
      ),
      SyncStatusVisualKind.waiting => const _IndicatorColors(
        background: AppColors.surfaceAlt,
        foreground: AppColors.textMuted,
        border: AppColors.borderSubtle,
      ),
      SyncStatusVisualKind.pending => const _IndicatorColors(
        background: AppColors.surfaceAlt,
        foreground: AppColors.accentSecondary,
        border: AppColors.borderSubtle,
      ),
      SyncStatusVisualKind.idle => const _IndicatorColors(
        background: AppColors.surfaceAlt,
        foreground: AppColors.textMuted,
        border: AppColors.borderSubtle,
      ),
    };
  }
}
