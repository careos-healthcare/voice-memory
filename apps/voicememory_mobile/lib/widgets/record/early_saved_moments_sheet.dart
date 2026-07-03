import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/user_facing_date.dart';
import '../../features/early_archive/early_saved_moments_analytics.dart';
import '../../features/early_archive/early_saved_moments_copy.dart';
import '../../features/early_archive/early_saved_moments_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Read-only bottom sheet for reviewing saved moments in the early Record flow.
class EarlySavedMomentsSheet extends StatelessWidget {
  const EarlySavedMomentsSheet({
    super.key,
    required this.content,
    required this.entryCount,
  });

  final EarlySavedMomentsSheetContent content;
  final int entryCount;

  static Future<void> show(
    BuildContext context, {
    required EarlySavedMomentsSheetContent content,
    required int entryCount,
  }) {
    unawaited(
      EarlySavedMomentsAnalytics.viewed(
        entryCount: entryCount,
        hasConfirmedRepeat: content.hasConfirmedRepeat,
      ),
    );
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => EarlySavedMomentsSheet(
        content: content,
        entryCount: entryCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            key: const Key('early_saved_moments_sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                EarlySavedMomentsCopy.sheetTitle,
                key: const Key('early_saved_moments_sheet_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                EarlySavedMomentsCopy.sheetSubtitle,
                key: const Key('early_saved_moments_sheet_subtitle'),
                style:
                    ArchiveMobileTypography.responsiveHelper(context).copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _SheetSection(
                label: EarlySavedMomentsCopy.savedMomentsSectionTitle,
                labelKey: 'early_saved_moments_section_saved',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final moment in content.moments) ...[
                      _SavedMomentRow(moment: moment),
                      if (moment != content.moments.last)
                        const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
              if (content.comparisonBody case final comparisonBody?) ...[
                const SizedBox(height: AppSpacing.md),
                _SheetSection(
                  label: EarlySavedMomentsCopy.comparingSectionTitle,
                  labelKey: 'early_saved_moments_section_comparing',
                  child: Text(
                    comparisonBody,
                    key: const Key('early_saved_moments_comparing_body'),
                    style: ArchiveMobileTypography.explanationBody(context)
                        .copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _SheetSection(
                label: EarlySavedMomentsCopy.nextRecordSectionTitle,
                labelKey: 'early_saved_moments_section_next',
                child: Text(
                  content.nextActionBody,
                  key: const Key('early_saved_moments_next_action_body'),
                  style: ArchiveMobileTypography.explanationBody(context)
                      .copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  const _SheetSection({
    required this.label,
    required this.labelKey,
    required this.child,
  });

  final String label;
  final String labelKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          key: Key(labelKey),
          style: ArchiveMobileTypography.cardLabel(context).copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}

class _SavedMomentRow extends StatelessWidget {
  const _SavedMomentRow({required this.moment});

  final EarlySavedMomentPreview moment;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('early_saved_moment_row_${moment.index}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          moment.label,
          key: Key('early_saved_moment_label_${moment.index}'),
          style: ArchiveMobileTypography.cardLabel(context).copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          moment.previewText,
          key: Key('early_saved_moment_preview_${moment.index}'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: ArchiveMobileTypography.explanationBody(context).copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          formatUserFacingDate(moment.savedAt),
          key: Key('early_saved_moment_saved_at_${moment.index}'),
          style: ArchiveMobileTypography.explanationBody(context).copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
