import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/beta_readiness/beta_readiness_analytics.dart';
import '../../features/beta_readiness/beta_readiness_copy.dart';
import '../../features/beta_readiness/beta_readiness_engine.dart';
import '../../features/beta_readiness/beta_readiness_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Local beta readiness checklist — read-only release safety surface.
class BetaReadinessCheckSheet extends StatelessWidget {
  const BetaReadinessCheckSheet({
    super.key,
    required this.report,
    this.source = 'testing_archiveme_screen',
  });

  final BetaReadinessReport report;
  final String source;

  static Future<void> show(
    BuildContext context, {
    String source = 'testing_archiveme_screen',
  }) {
    BetaReadinessAnalytics.opened(source: source);
    final report = BetaReadinessEngine.build();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: BetaReadinessCheckSheet(report: report, source: source),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('beta_readiness_check_sheet'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              report.title,
              key: const Key('beta_readiness_check_title'),
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              report.intro,
              key: const Key('beta_readiness_check_intro'),
              style: ArchiveMobileTypography.explanationBody(context).copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final section in report.sections) ...[
              _SectionBlock(section: section),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              BetaReadinessCopy.sectionReleaseWarnings,
              key: const Key('beta_readiness_warnings_heading'),
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final warning in report.warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  warning.text,
                  key: Key(
                    'beta_readiness_warning_${report.warnings.indexOf(warning)}',
                  ),
                  style: ArchiveMobileTypography.explanationBody(context).copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.section});

  final BetaReadinessSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('beta_readiness_section_${section.id.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          section.title,
          key: Key('beta_readiness_section_title_${section.id.name}'),
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final item in section.items)
          _ItemRow(item: item),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final BetaReadinessItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              item.label,
              key: Key('beta_readiness_item_label_${item.id.name}'),
              style: ArchiveMobileTypography.listTitle(context).copyWith(
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            item.status.label,
            key: Key('beta_readiness_item_status_${item.id.name}'),
            style: ArchiveMobileTypography.listTitle(context).copyWith(
              fontSize: 13,
              color: _statusColor(item.status),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(BetaReadinessItemStatus status) => switch (status) {
        BetaReadinessItemStatus.pass => AppColors.success,
        BetaReadinessItemStatus.needsManualCheck => AppColors.textSecondary,
        BetaReadinessItemStatus.notAvailable => AppColors.error,
      };
}
