import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_backup_bridge/archive_backup_bridge_analytics.dart';
import '../../features/archive_backup_bridge/archive_backup_bridge_engine.dart';
import '../../features/archive_backup_bridge/archive_backup_bridge_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Detail sheet for archive preservation — no live cloud backup claims.
class ArchiveBackupBridgeSheet extends StatelessWidget {
  const ArchiveBackupBridgeSheet({
    super.key,
    required this.contextData,
    this.onSeePro,
  });

  final ArchiveBackupBridgeContext contextData;
  final VoidCallback? onSeePro;

  static Future<void> show(
    BuildContext context, {
    required ArchiveBackupBridgeContext contextData,
    VoidCallback? onSeePro,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ArchiveBackupBridgeSheet(
        contextData: contextData,
        onSeePro: onSeePro,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final display = ArchiveBackupBridgeEngine.buildDisplay();
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );
    final showProCta = ArchiveBackupBridgeEngine.showProCta(contextData);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                display.sheetTitle,
                key: const Key('archive_backup_bridge_sheet_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                display.sheetIntro,
                key: const Key('archive_backup_bridge_sheet_intro'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                display.title,
                key: const Key('archive_backup_bridge_sheet_card_title'),
                style: ArchiveMobileTypography.listTitle(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                display.body,
                key: const Key('archive_backup_bridge_sheet_body'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                display.deviceBackupToday,
                key: const Key('archive_backup_bridge_sheet_device_backup'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                display.sheetLocalBackupLine,
                key: const Key('archive_backup_bridge_sheet_local_backup'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                display.plannedProAreas,
                key: const Key('archive_backup_bridge_sheet_planned_pro'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                display.proPreservation,
                key: const Key('archive_backup_bridge_sheet_pro_preservation'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.md),
              if (showProCta && onSeePro != null)
                FilledButton(
                  key: const Key('archive_backup_bridge_sheet_see_pro'),
                  onPressed: () {
                    ArchiveBackupBridgeAnalytics.ctaTapped(
                      source: contextData.surface.analyticsValue,
                      entryCount: contextData.entryCount,
                      hasConfirmedRepeat: contextData.hasConfirmedRepeat,
                      hasReportPreview: contextData.hasReportPreview,
                      actionType: 'see_pro',
                    );
                    Navigator.of(context).pop();
                    onSeePro!();
                  },
                  child: Text(display.sheetSeeProCta),
                ),
              if (showProCta && onSeePro != null)
                const SizedBox(height: AppSpacing.xs),
              TextButton(
                key: const Key('archive_backup_bridge_sheet_close'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(display.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
