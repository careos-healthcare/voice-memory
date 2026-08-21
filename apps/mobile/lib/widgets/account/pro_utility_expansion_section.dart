import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/beta_improvement/pro_utility_boundary_model.dart';
import 'package:archiveme_mobile/features/beta_improvement/pro_utility_branch_engine.dart';
import 'package:archiveme_mobile/features/beta_improvement/pro_utility_copy_fix.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Single Pro utility card — history, export, and private report preview rows.
class ProUtilityExpansionSection extends StatelessWidget {
  const ProUtilityExpansionSection({
    required this.entryCount, required this.hasMeaningfulProof, super.key,
    this.compact = false,
  });

  final int entryCount;
  final bool hasMeaningfulProof;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final model = ProUtilityBranchEngine.build(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
    );
    final rows = ProUtilityBranchEngine.utilityRows(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
    );
    if (!model.shouldShowSection || rows.isEmpty) {
      return const SizedBox.shrink(key: Key('pro_utility_expansion_hidden'));
    }

    final bodyStyle = ArchiveMobileTypography.body(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.35);
    final rowTitleStyle = ArchiveMobileTypography.listTitle(context);

    return Container(
      key: const Key('pro_utility_expansion_section'),
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: compact ? AppColors.surfaceAlt : const Color(0xFFF8FAF8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ProUtilityCopyFix.headline,
            key: const Key('pro_utility_expansion_headline'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ProUtilityCopyFix.subheadline,
            key: const Key('pro_utility_expansion_subheadline'),
            style: bodyStyle,
          ),
          if (model.isPreviewOnly) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              ProUtilityCopyFix.previewHonesty,
              key: const Key('pro_utility_expansion_preview_honesty'),
              style: bodyStyle.copyWith(color: AppColors.textSecondary),
            ),
          ],
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
            _UtilityRow(
              row: rows[i],
              titleStyle: rowTitleStyle,
              bodyStyle: bodyStyle,
              rowKey: Key('pro_utility_row_${rows[i].title}'),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            ProUtilityCopyFix.notMoreAiLine,
            key: const Key('pro_utility_expansion_not_more_ai'),
            style: bodyStyle.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _UtilityRow extends StatelessWidget {
  const _UtilityRow({
    required this.row,
    required this.titleStyle,
    required this.bodyStyle,
    required this.rowKey,
  });

  final ProUtilityRow row;
  final TextStyle titleStyle;
  final TextStyle bodyStyle;
  final Key rowKey;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      key: rowKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(row.title, style: titleStyle),
        const SizedBox(height: AppSpacing.xs),
        Text(row.body, style: bodyStyle),
      ],
    );

    if (row.route == null) return content;

    return InkWell(
      onTap: () => context.push(row.route!),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: content),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}