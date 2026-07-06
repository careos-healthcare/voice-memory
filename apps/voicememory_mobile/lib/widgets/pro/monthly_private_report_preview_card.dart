import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/monthly_private_report/monthly_private_report_analytics.dart';
import '../../features/monthly_private_report/monthly_private_report_engine.dart';
import '../../features/monthly_private_report/monthly_private_report_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import 'monthly_private_report_preview_sheet.dart';

/// Compact card for the forming monthly private report preview.
class MonthlyPrivateReportPreviewCard extends StatefulWidget {
  const MonthlyPrivateReportPreviewCard({
    super.key,
    required this.surface,
    required this.entryCount,
    required this.preview,
    required this.onSeePro,
    required this.onDismiss,
  });

  final MonthlyPrivateReportSurface surface;
  final int entryCount;
  final MonthlyPrivateReportPreview preview;
  final VoidCallback onSeePro;
  final VoidCallback onDismiss;

  @override
  State<MonthlyPrivateReportPreviewCard> createState() =>
      _MonthlyPrivateReportPreviewCardState();
}

class _MonthlyPrivateReportPreviewCardState
    extends State<MonthlyPrivateReportPreviewCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    MonthlyPrivateReportAnalytics.seen(
      source: widget.surface.analyticsValue,
      entryCount: widget.entryCount,
      hasConfirmedRepeat: widget.preview.hasConfirmedRepeat,
      hasChangeSignal: widget.preview.hasChangeSignal,
      hasHelpedSignal: widget.preview.hasHelpedSignal,
      hasQuietSignal: widget.preview.hasQuietSignal,
    );
  }

  Future<void> _openSheet() async {
    MonthlyPrivateReportAnalytics.ctaTapped(
      source: widget.surface.analyticsValue,
      entryCount: widget.entryCount,
      hasConfirmedRepeat: widget.preview.hasConfirmedRepeat,
      hasChangeSignal: widget.preview.hasChangeSignal,
      hasHelpedSignal: widget.preview.hasHelpedSignal,
      hasQuietSignal: widget.preview.hasQuietSignal,
      actionType: 'open_sheet',
    );
    await MonthlyPrivateReportPreviewSheet.show(
      context,
      surface: widget.surface,
      entryCount: widget.entryCount,
      preview: widget.preview,
      onSeePro: widget.onSeePro,
    );
  }

  void _handleDismiss() {
    MonthlyPrivateReportAnalytics.dismissed(
      source: widget.surface.analyticsValue,
      entryCount: widget.entryCount,
      hasConfirmedRepeat: widget.preview.hasConfirmedRepeat,
      hasChangeSignal: widget.preview.hasChangeSignal,
      hasHelpedSignal: widget.preview.hasHelpedSignal,
      hasQuietSignal: widget.preview.hasQuietSignal,
    );
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();
    final display = MonthlyPrivateReportEngine.buildDisplay();
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );

    return Container(
      key: const Key('monthly_private_report_preview_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            display.title,
            key: const Key('monthly_private_report_preview_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            display.body,
            key: const Key('monthly_private_report_preview_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            display.proReason,
            key: const Key('monthly_private_report_preview_pro_reason'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('monthly_private_report_preview_dismiss'),
                  onPressed: _handleDismiss,
                  child: Text(display.secondary),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton(
                  key: const Key('monthly_private_report_preview_cta'),
                  onPressed: _openSheet,
                  child: Text(display.cta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
