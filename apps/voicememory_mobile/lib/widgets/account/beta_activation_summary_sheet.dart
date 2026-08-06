import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/beta_activation/beta_activation_summary_copy.dart';
import '../../features/beta_activation/beta_activation_summary_engine.dart';
import '../../features/beta_activation/beta_activation_summary_model.dart';
import '../../features/beta_activation/beta_activation_summary_tracker.dart';
import '../../features/share/archive_share_actions.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Local beta progress summary — metadata counters only.
class BetaActivationSummarySheet extends StatefulWidget {
  const BetaActivationSummarySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: const BetaActivationSummarySheet(),
      ),
    );
  }

  @override
  State<BetaActivationSummarySheet> createState() =>
      _BetaActivationSummarySheetState();
}

class _BetaActivationSummarySheetState
    extends State<BetaActivationSummarySheet> {
  BetaActivationSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await BetaActivationSummaryTracker.loadAll();
    if (!mounted) return;
    setState(() {
      _summary = BetaActivationSummaryEngine.build(
        loop: loaded.loop,
        extension: loaded.extension,
      );
      _loading = false;
    });
  }

  Future<void> _copySummary() async {
    final summary = _summary;
    if (summary == null) return;
    final outcome = await ArchiveShareActions.copyShareText(
      context,
      text: BetaActivationSummaryEngine.buildCopyText(summary),
      showConfirmation: false,
    );
    if (!mounted) return;
    if (outcome == ArchiveShareOutcome.copied ||
        outcome == ArchiveShareOutcome.fallbackCopied) {
      ArchiveShareActions.showFeedback(
        context,
        BetaActivationSummaryCopy.summaryCopied,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SafeArea(
        child: SizedBox(
          key: Key('beta_activation_summary_loading'),
          height: 120,
        ),
      );
    }

    final summary = _summary!;
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary);

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
            key: const Key('beta_activation_summary_sheet'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                BetaActivationSummaryCopy.sheetTitle,
                key: const Key('beta_activation_summary_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(BetaActivationSummaryCopy.sheetIntro, style: bodyStyle),
              const SizedBox(height: AppSpacing.md),
              Text(
                BetaActivationSummaryCopy.statusHeading,
                style: ArchiveMobileTypography.cardLabel(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                BetaActivationSummaryCopy.statusLabel(summary.status),
                key: const Key('beta_activation_summary_status'),
                style: ArchiveMobileTypography.listTitle(context),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                BetaActivationSummaryCopy.countersHeading,
                style: ArchiveMobileTypography.cardLabel(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              _row(
                context,
                key: 'app_opens',
                label: BetaActivationSummaryCopy.appOpens,
                value: summary.appOpens,
              ),
              _row(
                context,
                key: 'record_screen_views',
                label: BetaActivationSummaryCopy.recordScreenViews,
                value: summary.recordScreenViews,
              ),
              _row(
                context,
                key: 'first_moment_saved',
                label: BetaActivationSummaryCopy.firstMomentSaved,
                value: summary.firstMomentSaved,
              ),
              _row(
                context,
                key: 'second_moment_saved',
                label: BetaActivationSummaryCopy.secondMomentSaved,
                value: summary.secondMomentSaved,
              ),
              _row(
                context,
                key: 'first_proof_reached',
                label: BetaActivationSummaryCopy.firstProofReached,
                value: summary.firstProofReached,
              ),
              _row(
                context,
                key: 'patterns_opened',
                label: BetaActivationSummaryCopy.patternsOpened,
                value: summary.patternsOpened,
              ),
              _row(
                context,
                key: 'pattern_details_opened',
                label: BetaActivationSummaryCopy.patternDetailsOpened,
                value: summary.patternDetailsOpened,
              ),
              _row(
                context,
                key: 'weekly_review_opened',
                label: BetaActivationSummaryCopy.weeklyReviewOpened,
                value: summary.weeklyReviewOpened,
              ),
              _row(
                context,
                key: 'return_day_flow_answered',
                label: BetaActivationSummaryCopy.returnDayFlowAnswered,
                value: summary.returnDayFlowAnswered,
              ),
              _row(
                context,
                key: 'transcript_corrected',
                label: BetaActivationSummaryCopy.transcriptCorrected,
                value: summary.transcriptCorrected,
              ),
              _row(
                context,
                key: 'beta_feedback_opened',
                label: BetaActivationSummaryCopy.betaFeedbackOpened,
                value: summary.betaFeedbackOpened,
              ),
              _row(
                context,
                key: 'beta_feedback_submitted',
                label: BetaActivationSummaryCopy.betaFeedbackSubmitted,
                value: summary.betaFeedbackSubmitted,
              ),
              _row(
                context,
                key: 'first_proof_truth_yes',
                label: BetaActivationSummaryCopy.firstProofTruthYes,
                value: summary.firstProofTruthYes,
              ),
              _row(
                context,
                key: 'first_proof_truth_sort_of',
                label: BetaActivationSummaryCopy.firstProofTruthSortOf,
                value: summary.firstProofTruthSortOf,
              ),
              _row(
                context,
                key: 'first_proof_truth_no',
                label: BetaActivationSummaryCopy.firstProofTruthNo,
                value: summary.firstProofTruthNo,
              ),
              _row(
                context,
                key: 'first_proof_action_watch_this_next',
                label: BetaActivationSummaryCopy.firstProofActionWatchThisNext,
                value: summary.firstProofActionWatchThisNext,
              ),
              _row(
                context,
                key: 'first_proof_action_view_pattern_details',
                label: BetaActivationSummaryCopy
                    .firstProofActionViewPatternDetails,
                value: summary.firstProofActionViewPatternDetails,
              ),
              _row(
                context,
                key: 'first_proof_action_rename_pattern',
                label: BetaActivationSummaryCopy.firstProofActionRenamePattern,
                value: summary.firstProofActionRenamePattern,
              ),
              _row(
                context,
                key: 'first_proof_action_keep_recording',
                label: BetaActivationSummaryCopy.firstProofActionKeepRecording,
                value: summary.firstProofActionKeepRecording,
              ),
              _row(
                context,
                key: 'first_proof_action_correct_transcript',
                label:
                    BetaActivationSummaryCopy.firstProofActionCorrectTranscript,
                value: summary.firstProofActionCorrectTranscript,
              ),
              _row(
                context,
                key: 'first_proof_action_remove_from_pattern',
                label:
                    BetaActivationSummaryCopy.firstProofActionRemoveFromPattern,
                value: summary.firstProofActionRemoveFromPattern,
              ),
              _row(
                context,
                key: 'pro_screen_opened',
                label: BetaActivationSummaryCopy.proScreenOpened,
                value: summary.proScreenOpened,
              ),
              _row(
                context,
                key: 'restore_purchases_tapped',
                label: BetaActivationSummaryCopy.restorePurchasesTapped,
                value: summary.restorePurchasesTapped,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                key: const Key('beta_activation_summary_copy'),
                onPressed: _copySummary,
                child: const Text(BetaActivationSummaryCopy.copySummaryButton),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String key,
    required String label,
    required int value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              key: Key('beta_activation_summary_label_$key'),
              style: ArchiveMobileTypography.explanationBody(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ),
          Text(
            '$value',
            key: Key('beta_activation_summary_value_$key'),
            style: ArchiveMobileTypography.explanationBody(context),
          ),
        ],
      ),
    );
  }
}
