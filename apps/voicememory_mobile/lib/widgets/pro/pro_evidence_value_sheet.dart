import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/beta_feedback_intelligence/beta_feedback_intelligence_store.dart';
import '../../features/pro_evidence_value/pro_evidence_value_analytics.dart';
import '../../features/pro_evidence_value/pro_evidence_value_engine.dart';
import '../../features/pro_evidence_value/pro_evidence_value_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Sheet explaining Free vs Pro evidence value and ChatGPT differentiation.
class ProEvidenceValueSheet extends StatelessWidget {
  const ProEvidenceValueSheet({
    super.key,
    required this.surface,
    required this.entryCount,
    required this.onSeePro,
  });

  final ProEvidenceValueSurface surface;
  final int entryCount;
  final VoidCallback onSeePro;

  static Future<void> show(
    BuildContext context, {
    required ProEvidenceValueSurface surface,
    required int entryCount,
    required VoidCallback onSeePro,
  }) {
    unawaited(BetaFeedbackIntelligenceStore.markProEvidenceSheetOpened());
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ProEvidenceValueSheet(
        surface: surface,
        entryCount: entryCount,
        onSeePro: onSeePro,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final display = ProEvidenceValueEngine.buildDisplay();
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final helperStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );
    final sectionStyle = ArchiveMobileTypography.listTitle(context).copyWith(
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
                key: const Key('pro_evidence_value_sheet_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                display.comparesMomentsLine,
                key: const Key('pro_evidence_value_sheet_compares_line'),
                style: helperStyle,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                display.freeSectionTitle,
                key: const Key('pro_evidence_value_sheet_free_title'),
                style: sectionStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final bullet in display.freeBullets) ...[
                _Bullet(text: bullet, style: bodyStyle),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                display.proSectionTitle,
                key: const Key('pro_evidence_value_sheet_pro_title'),
                style: sectionStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final bullet in display.proBullets) ...[
                _Bullet(
                  text: bullet,
                  style: bodyStyle,
                  bulletKey: Key('pro_evidence_value_sheet_pro_$bullet'),
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                display.evidenceLine,
                key: const Key('pro_evidence_value_sheet_evidence_line'),
                style: helperStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                display.chatGptDifferentiationLine,
                key: const Key('pro_evidence_value_sheet_chatgpt_line'),
                style: helperStyle,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                display.sheetFooter,
                key: const Key('pro_evidence_value_sheet_footer'),
                style: helperStyle.copyWith(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                key: const Key('pro_evidence_value_sheet_see_pro'),
                onPressed: () {
                  ProEvidenceValueAnalytics.ctaTapped(
                    source: surface.analyticsValue,
                    entryCount: entryCount,
                    actionType: 'see_pro',
                  );
                  Navigator.of(context).pop();
                  onSeePro();
                },
                child: Text(display.cta),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                key: const Key('pro_evidence_value_sheet_close'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({
    required this.text,
    required this.style,
    this.bulletKey,
  });

  final String text;
  final TextStyle style;
  final Key? bulletKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• ', style: style),
        Expanded(
          child: Text(text, key: bulletKey, style: style),
        ),
      ],
    );
  }
}
