import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/beta_activation/beta_activation_summary_tracker.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pro_memory/pro_memory_boundary_copy.dart';
import '../../features/pro_memory/pro_memory_boundary_engine.dart';
import '../../features/weekly_review/weekly_archive_review_copy.dart';
import '../../features/weekly_review/weekly_archive_review_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../archive_paywall/pro_memory_upgrade_bridge.dart';
import '../account/beta_feedback_sheet.dart';

/// Full weekly archive review in a bottom sheet.
class WeeklyArchiveReviewSheet extends StatelessWidget {
  const WeeklyArchiveReviewSheet({
    super.key,
    required this.review,
    this.isPro = true,
    this.onSeePro,
    this.entryCount = 0,
  });

  final WeeklyArchiveReviewResult review;
  final bool isPro;
  final VoidCallback? onSeePro;
  final int entryCount;

  static Future<void> show(
    BuildContext context, {
    required WeeklyArchiveReviewResult review,
    bool isPro = true,
    VoidCallback? onSeePro,
    int entryCount = 0,
  }) {
    unawaited(BetaActivationSummaryTracker.trackWeeklyReviewOpened());
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: WeeklyArchiveReviewSheet(
          review: review,
          isPro: isPro,
          onSeePro: onSeePro,
          entryCount: entryCount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final fallbackStyle = bodyStyle.copyWith(
      color: AppColors.textSecondary,
      fontStyle: FontStyle.italic,
    );
    final evidenceStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.35,
      fontSize: 12,
    );

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
            key: const Key('weekly_archive_review_sheet'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                review.title,
                key: const Key('weekly_archive_review_sheet_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(context),
              ),
              if (review.state == WeeklyArchiveReviewState.full &&
                  review.subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  review.subtitle!,
                  key: const Key('weekly_archive_review_sheet_subtitle'),
                  style: ArchiveMobileTypography.explanationBody(context).copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (review.state == WeeklyArchiveReviewState.forming &&
                  review.formingBody != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  review.formingBody!,
                  key: const Key('weekly_archive_review_sheet_forming_body'),
                  style: bodyStyle.copyWith(color: AppColors.textSecondary),
                ),
              ],
              if (review.state == WeeklyArchiveReviewState.full) ...[
                if (review.whatRepeated case final section?
                    when ProMemoryBoundaryEngine.includeWeeklyReviewSection(
                      sectionIndex: 0,
                      isPro: isPro,
                    )) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Section(
                    label: section.label,
                    labelKey: 'weekly_archive_review_repeated_label',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          section.body,
                          key: const Key('weekly_archive_review_repeated_body'),
                          style: section.isSupported ? bodyStyle : fallbackStyle,
                        ),
                        for (final phrase in section.evidencePhrases.skip(1))
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(phrase, style: evidenceStyle),
                          ),
                      ],
                    ),
                  ),
                ],
                if (review.whatChanged case final section?
                    when ProMemoryBoundaryEngine.includeWeeklyReviewSection(
                      sectionIndex: 1,
                      isPro: isPro,
                    )) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _Section(
                    label: section.label,
                    labelKey: 'weekly_archive_review_changed_label',
                    child: Text(
                      section.body,
                      key: const Key('weekly_archive_review_changed_body'),
                      style: section.isSupported ? bodyStyle : fallbackStyle,
                    ),
                  ),
                ],
                if (review.whatHelped case final section?
                    when ProMemoryBoundaryEngine.includeWeeklyReviewSection(
                      sectionIndex: 2,
                      isPro: isPro,
                    )) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _Section(
                    label: section.label,
                    labelKey: 'weekly_archive_review_helped_label',
                    child: Text(
                      section.body,
                      key: const Key('weekly_archive_review_helped_body'),
                      style: section.isSupported ? bodyStyle : fallbackStyle,
                    ),
                  ),
                ],
                if (review.whatToWatchNext case final section?
                    when ProMemoryBoundaryEngine.includeWeeklyReviewSection(
                      sectionIndex: 3,
                      isPro: isPro,
                    )) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _Section(
                    label: section.label,
                    labelKey: 'weekly_archive_review_watch_label',
                    child: Text(
                      section.body,
                      key: const Key('weekly_archive_review_watch_body'),
                      style: bodyStyle.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
                if (ProMemoryBoundaryEngine.showWeeklyReviewPreviewNote(
                  isPro: isPro,
                ) &&
                    ProMemoryBoundaryEngine.hasGatedWeeklyReviewSections(
                      review: review,
                      isPro: isPro,
                    )) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    ProMemoryBoundaryCopy.weeklyReviewPreviewTitle,
                    key: const Key('weekly_archive_review_preview_title'),
                    style: ArchiveMobileTypography.listTitle(context).copyWith(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    ProMemoryBoundaryCopy.weeklyReviewPreviewBody,
                    key: const Key('weekly_archive_review_preview_body'),
                    style: bodyStyle.copyWith(color: AppColors.textSecondary),
                  ),
                ],
                if (!isPro &&
                    onSeePro != null &&
                    ProMemoryBoundaryEngine.hasGatedWeeklyReviewSections(
                      review: review,
                      isPro: isPro,
                    )) ...[
                  const SizedBox(height: AppSpacing.md),
                  ProMemoryUpgradeBridge(
                    compact: true,
                    showNotNow: false,
                    onSeePro: onSeePro!,
                  ),
                ],
              ],
              const SizedBox(height: AppSpacing.sm),
              BetaFeedbackLink(
                source: 'weekly_review',
                entryCount: entryCount,
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('weekly_archive_review_sheet_close'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(WeeklyArchiveReviewCopy.closeCta),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
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
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: 2),
        child,
      ],
    );
  }
}
