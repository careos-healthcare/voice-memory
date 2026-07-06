import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/monthly_private_report/monthly_private_report_analytics.dart';
import '../../features/monthly_private_report/monthly_private_report_copy.dart';
import '../../features/monthly_private_report/monthly_private_report_engine.dart';
import '../../features/monthly_private_report/monthly_private_report_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Detail sheet for the forming monthly private report preview.
class MonthlyPrivateReportPreviewSheet extends StatelessWidget {
  const MonthlyPrivateReportPreviewSheet({
    super.key,
    required this.surface,
    required this.entryCount,
    required this.preview,
    required this.onSeePro,
  });

  final MonthlyPrivateReportSurface surface;
  final int entryCount;
  final MonthlyPrivateReportPreview preview;
  final VoidCallback onSeePro;

  static Future<void> show(
    BuildContext context, {
    required MonthlyPrivateReportSurface surface,
    required int entryCount,
    required MonthlyPrivateReportPreview preview,
    required VoidCallback onSeePro,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => MonthlyPrivateReportPreviewSheet(
        surface: surface,
        entryCount: entryCount,
        preview: preview,
        onSeePro: onSeePro,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final display = MonthlyPrivateReportEngine.buildDisplay();
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );
    final sectionTitleStyle = ArchiveMobileTypography.listTitle(context).copyWith(
      fontSize: 16,
    );

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
                key: const Key('monthly_private_report_preview_sheet_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                display.sheetIntro,
                key: const Key('monthly_private_report_preview_sheet_intro'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final section in preview.sections) ...[
                Text(
                  section.heading,
                  key: Key(
                    'monthly_private_report_preview_section_${section.type.name}',
                  ),
                  style: sectionTitleStyle,
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final line in section.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(line, style: bodyStyle),
                  ),
                for (final bullet in section.bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text('• $bullet', style: bodyStyle),
                  ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Text(
                MonthlyPrivateReportCopy.basedOnSavedMoments,
                key: const Key('monthly_private_report_preview_based_on_moments'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                display.proReason,
                key: const Key('monthly_private_report_preview_sheet_pro_reason'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                display.chatDifferentiation,
                key: const Key('monthly_private_report_preview_sheet_chat_line'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                display.proValueLine,
                key: const Key('monthly_private_report_preview_sheet_pro_value'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                key: const Key('monthly_private_report_preview_sheet_see_pro'),
                onPressed: () {
                  MonthlyPrivateReportAnalytics.ctaTapped(
                    source: surface.analyticsValue,
                    entryCount: entryCount,
                    hasConfirmedRepeat: preview.hasConfirmedRepeat,
                    hasChangeSignal: preview.hasChangeSignal,
                    hasHelpedSignal: preview.hasHelpedSignal,
                    hasQuietSignal: preview.hasQuietSignal,
                    actionType: 'see_pro',
                  );
                  Navigator.of(context).pop();
                  onSeePro();
                },
                child: Text(display.sheetSeeProCta),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                key: const Key('monthly_private_report_preview_sheet_close'),
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
