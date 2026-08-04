import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/beta_activation/beta_activation_summary_tracker.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/belief_change/belief_change_moment_model.dart';
import '../../features/weekly_review/weekly_archive_review_copy.dart';
import '../../features/weekly_review/weekly_archive_review_model.dart';
import '../../features/private_report/private_report_copy.dart';
import '../../features/private_report/private_report_engine.dart';
import '../../features/repeat_return_check/repeat_return_check_store.dart';
import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../../features/pattern_confidence/pattern_confidence_model.dart';
import '../../features/pattern_lifecycle/pattern_lifecycle_model.dart';
import '../../features/quiet_signal/quiet_signal_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../patterns/belief_change_moment_card.dart';
import '../patterns/pattern_confidence_badge.dart';
import '../patterns/pattern_lifecycle_badge.dart';
import '../common/contextual_privacy_reassurance.dart';
import '../account/beta_feedback_sheet.dart';

/// Full weekly archive review in a bottom sheet.
class WeeklyArchiveReviewSheet extends StatelessWidget {
  const WeeklyArchiveReviewSheet({
    super.key,
    required this.review,
    this.isPro = true,
    this.onSeePro,
    this.entryCount = 0,
    this.beliefChangeMoment,
    this.patternConfidence,
    this.patternLifecycle,
    this.quietSignal,
    this.entries = const [],
  });

  final WeeklyArchiveReviewResult review;
  final bool isPro;
  final VoidCallback? onSeePro;
  final int entryCount;
  final List<JournalEntry> entries;
  final BeliefChangeMoment? beliefChangeMoment;
  final PatternConfidence? patternConfidence;
  final PatternLifecycle? patternLifecycle;
  final QuietSignal? quietSignal;

  static Future<void> show(
    BuildContext context, {
    required WeeklyArchiveReviewResult review,
    bool isPro = true,
    VoidCallback? onSeePro,
    int entryCount = 0,
    BeliefChangeMoment? beliefChangeMoment,
    PatternConfidence? patternConfidence,
    PatternLifecycle? patternLifecycle,
    QuietSignal? quietSignal,
    List<JournalEntry> entries = const [],
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
          beliefChangeMoment: beliefChangeMoment,
          patternConfidence: patternConfidence,
          patternLifecycle: patternLifecycle,
          quietSignal: quietSignal,
          entries: entries,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final fallbackStyle = bodyStyle.copyWith(
      color: AppColors.textSecondary,
      fontStyle: FontStyle.italic,
    );
    final evidenceStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.35, fontSize: 12);

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
              const SizedBox(height: 2),
              Text(
                'Non-AI evidence summary',
                key: const Key('weekly_archive_review_sheet_non_ai_label'),
                style: ArchiveMobileTypography.cardLabel(context),
              ),
              if (review.state == WeeklyArchiveReviewState.full &&
                  review.subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  review.subtitle!,
                  key: const Key('weekly_archive_review_sheet_subtitle'),
                  style: ArchiveMobileTypography.explanationBody(
                    context,
                  ).copyWith(color: AppColors.textSecondary),
                ),
              ],
              if (patternLifecycle != null) ...[
                const SizedBox(height: AppSpacing.sm),
                PatternLifecycleBadge(
                  lifecycle: patternLifecycle!,
                  entryCount: entryCount,
                  source: 'weekly_review',
                ),
              ],
              if (patternConfidence != null) ...[
                const SizedBox(height: AppSpacing.sm),
                PatternConfidenceBadge(
                  confidence: patternConfidence!,
                  showBody: true,
                ),
              ],
              if (beliefChangeMoment != null) ...[
                const SizedBox(height: AppSpacing.md),
                BeliefChangeMomentCard(
                  moment: beliefChangeMoment!,
                  entryCount: entryCount,
                  source: 'weekly_review',
                  compact: true,
                  showPrivacyReassurance: false,
                  showProPackagingBridge: false,
                ),
              ],
              if (quietSignal != null) ...[
                const SizedBox(height: AppSpacing.md),
                _Section(
                  label: quietSignal!.weeklyReviewHeading ?? '',
                  labelKey: 'weekly_archive_review_quiet_signal_label',
                  child: Text(
                    quietSignal!.weeklyReviewBody ?? '',
                    key: const Key('weekly_archive_review_quiet_signal_body'),
                    style: bodyStyle.copyWith(color: AppColors.textSecondary),
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
                if (review.whatRepeated case final section?) ...[
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
                          style: section.isSupported
                              ? bodyStyle
                              : fallbackStyle,
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
                if (review.whatChanged case final section?) ...[
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
                if (review.whatHelped case final section?) ...[
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
                if (review.whatToWatchNext case final section?) ...[
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
              ],
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('private_report_open_link'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () async {
                    if (!AppServices.isInitialized) return;
                    final entries = await AppServices.instance.journal
                        .loadAll();
                    if (!context.mounted) return;
                    await PrivateReportEngine.showSheet(
                      context,
                      entries: entries,
                      source: 'weekly_review',
                      isPro: isPro,
                      returnChecks: RepeatReturnCheckStore.cached,
                      viewingConfirmedRepeatOrTimeline: true,
                    );
                  },
                  child: Text(
                    PrivateReportCopy.openReportCta,
                    style: ArchiveMobileTypography.responsiveHelper(context)
                        .copyWith(
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.underline,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              BetaFeedbackLink(source: 'weekly_review', entryCount: entryCount),
              const SizedBox(height: AppSpacing.sm),
              ContextualPrivacyReassurance(
                source: 'weekly_review',
                entryCount: entryCount,
                compact: false,
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
