import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/beta_test_script/beta_test_script_analytics.dart';
import '../../features/beta_test_script/beta_test_script_copy.dart';
import '../../features/beta_test_script/beta_test_script_engine.dart';
import '../../features/beta_test_script/beta_test_script_model.dart';
import '../../features/beta_test_script/beta_test_script_store.dart';
import '../../models/journal_entry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../account/beta_feedback_sheet.dart';

/// Full 3-day beta tester script sheet.
class BetaTestScriptSheet extends StatefulWidget {
  const BetaTestScriptSheet({
    super.key,
    required this.plan,
    required this.source,
    this.onReset,
    this.onSendFeedback,
  });

  final BetaTestScriptPlan plan;
  final String source;
  final VoidCallback? onReset;
  final VoidCallback? onSendFeedback;

  static Future<void> show(
    BuildContext context, {
    required List<JournalEntry> entries,
    required String source,
    VoidCallback? onReset,
    VoidCallback? onSendFeedback,
  }) {
    final plan = BetaTestScriptEngine.buildPlan(entries: entries);
    BetaTestScriptAnalytics.opened(
      source: source,
      entryCount: plan.progress.entryCount,
    );
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: BetaTestScriptSheet(
          plan: plan,
          source: source,
          onReset: onReset,
          onSendFeedback: onSendFeedback,
        ),
      ),
    );
  }

  @override
  State<BetaTestScriptSheet> createState() => _BetaTestScriptSheetState();
}

class _BetaTestScriptSheetState extends State<BetaTestScriptSheet> {
  final Set<String> _trackedSteps = {};

  @override
  void initState() {
    super.initState();
    for (final day in widget.plan.days) {
      _trackStep(day.stepKey);
    }
    _trackStep('success_questions');
    _trackStep('failure_signal');
  }

  void _trackStep(String stepKey) {
    if (_trackedSteps.contains(stepKey)) return;
    _trackedSteps.add(stepKey);
    BetaTestScriptAnalytics.stepSeen(
      source: widget.source,
      step: stepKey,
      entryCount: widget.plan.progress.entryCount,
    );
    BetaTestScriptStore.instance().markStepSeen(stepKey);
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(BetaTestScriptCopy.resetTitle),
        content: Text(BetaTestScriptCopy.resetBody),
        actions: [
          TextButton(
            key: const Key('beta_test_script_reset_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(BetaTestScriptCopy.resetCancelCta),
          ),
          TextButton(
            key: const Key('beta_test_script_reset_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(BetaTestScriptCopy.resetConfirmCta),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await BetaTestScriptStore.instance().resetProgress();
    BetaTestScriptAnalytics.progressReset(source: widget.source);
    widget.onReset?.call();
    if (mounted) Navigator.of(context).pop();
  }

  void _openFeedback() {
    BetaTestScriptAnalytics.feedbackCtaTapped(
      source: widget.source,
      entryCount: widget.plan.progress.entryCount,
    );
    widget.onSendFeedback?.call();
    Navigator.of(context).pop();
    BetaFeedbackSheet.show(
      context,
      source: widget.source,
      entryCount: widget.plan.progress.entryCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );
    final labelStyle = ArchiveMobileTypography.cardLabel(context).copyWith(
      color: AppColors.textSecondary,
    );
    final progress = widget.plan.progress;

    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('beta_test_script_sheet'),
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
              widget.plan.title,
              key: const Key('beta_test_script_sheet_title'),
              style: titleStyle,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.plan.intro,
              key: const Key('beta_test_script_sheet_intro'),
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              BetaTestScriptCopy.progressHeading,
              key: const Key('beta_test_script_progress_heading'),
              style: labelStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            _ProgressRow(
              label: BetaTestScriptCopy.day1Label,
              value: progress.day1Label,
              labelKey: 'beta_test_script_progress_day1',
            ),
            _ProgressRow(
              label: BetaTestScriptCopy.day2Label,
              value: progress.day2Label,
              labelKey: 'beta_test_script_progress_day2',
            ),
            _ProgressRow(
              label: BetaTestScriptCopy.day3Label,
              value: progress.day3Label,
              labelKey: 'beta_test_script_progress_day3',
            ),
            _ProgressRow(
              label: BetaTestScriptCopy.firstProofLabel,
              value: progress.firstProofLabel,
              labelKey: 'beta_test_script_progress_first_proof',
            ),
            _ProgressRow(
              label: BetaTestScriptCopy.feedbackLabel,
              value: progress.feedbackLabel,
              labelKey: 'beta_test_script_progress_feedback',
            ),
            const SizedBox(height: AppSpacing.md),
            for (final day in widget.plan.days) ...[
              Text(
                day.title,
                key: Key('beta_test_script_day_title_${day.stepKey}'),
                style: titleStyle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                day.body,
                key: Key('beta_test_script_day_body_${day.stepKey}'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              for (var i = 0; i < day.checklist.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '• ${day.checklist[i]}',
                    key: Key('beta_test_script_day_check_${day.stepKey}_$i'),
                    style: bodyStyle,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              widget.plan.successHeading,
              key: const Key('beta_test_script_success_heading'),
              style: labelStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            for (var i = 0; i < widget.plan.successQuestions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• ${widget.plan.successQuestions[i]}',
                  key: Key('beta_test_script_success_question_$i'),
                  style: bodyStyle,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.plan.failureHeading,
              key: const Key('beta_test_script_failure_heading'),
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('beta_test_script_send_feedback'),
                onPressed: _openFeedback,
                child: Text(BetaTestScriptCopy.sendBetaFeedbackCta),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('beta_test_script_reset_progress'),
                onPressed: _confirmReset,
                child: Text(BetaTestScriptCopy.resetProgressCta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.labelKey,
  });

  final String label;
  final String value;
  final String labelKey;

  @override
  Widget build(BuildContext context) {
    final style = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '$label:',
              key: Key(labelKey),
              style: style,
            ),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}
