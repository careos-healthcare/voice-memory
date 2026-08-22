import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/settings/ui/trust_badge_copy.dart';
import 'package:archiveme_mobile/onboarding/onboarding_visuals.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Calm, factual summary of where processing happens and where the live
/// storage-protection state is reported.
class TrustBadge extends StatelessWidget {
  const TrustBadge({
    super.key,
    this.compact = false,
    this.useOnboardingTypography = false,
  });

  /// Hides supporting detail lines for dense settings surfaces.
  final bool compact;

  /// Uses onboarding typography when shown in first-run flows.
  final bool useOnboardingTypography;

  static const Key badgeKey = Key('trust_badge');
  static const Key onDeviceKey = Key('trust_badge_on_device');
  static const Key storageKey = Key('trust_badge_storage');

  @override
  Widget build(BuildContext context) {
    final titleStyle = useOnboardingTypography
        ? OnboardingTypography.label()
        : ArchiveMobileTypography.listTitle(context);
    final detailStyle = useOnboardingTypography
        ? OnboardingTypography.body(context, color: AppColors.textSecondary)
        : ArchiveMobileTypography.listSubtitle(context);

    return Semantics(
      container: true,
      label:
          '${TrustBadgeCopy.onDeviceProcessing}. '
          '${TrustBadgeCopy.onDeviceDetail} '
          '${TrustBadgeCopy.storage}. '
          '${TrustBadgeCopy.storageDetail}',
      child: Container(
        key: badgeKey,
        width: double.infinity,
        padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TrustLine(
              key: onDeviceKey,
              icon: Icons.memory_outlined,
              title: TrustBadgeCopy.onDeviceProcessing,
              detail: compact ? null : TrustBadgeCopy.onDeviceDetail,
              titleStyle: titleStyle,
              detailStyle: detailStyle,
            ),
            SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
            _TrustLine(
              key: storageKey,
              icon: Icons.lock_outline,
              title: TrustBadgeCopy.storage,
              detail: compact ? null : TrustBadgeCopy.storageDetail,
              titleStyle: titleStyle,
              detailStyle: detailStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustLine extends StatelessWidget {
  const _TrustLine({
    required this.icon,
    required this.title,
    required this.titleStyle,
    required this.detailStyle,
    super.key,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final TextStyle titleStyle;
  final TextStyle detailStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: AppColors.accentPrimary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: titleStyle),
              if (detail case final detailText?) ...[
                const SizedBox(height: 4),
                Text(detailText, style: detailStyle),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
