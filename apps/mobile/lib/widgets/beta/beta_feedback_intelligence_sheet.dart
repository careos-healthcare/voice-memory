import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_analytics.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_copy.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_model.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_store.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Structured beta feedback sheet — safe buckets only, no journal content.
class BetaFeedbackIntelligenceSheet extends StatefulWidget {
  const BetaFeedbackIntelligenceSheet({
    required this.source, required this.entryCount, required this.reachedFirstProof, super.key,
    this.onSubmitted,
  });

  final String source;
  final int entryCount;
  final bool reachedFirstProof;
  final VoidCallback? onSubmitted;

  static Future<void> show(
    BuildContext context, {
    required String source,
    required int entryCount,
    required bool reachedFirstProof,
    VoidCallback? onSubmitted,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: BetaFeedbackIntelligenceSheet(
          source: source,
          entryCount: entryCount,
          reachedFirstProof: reachedFirstProof,
          onSubmitted: onSubmitted,
        ),
      ),
    );
  }

  @override
  State<BetaFeedbackIntelligenceSheet> createState() =>
      _BetaFeedbackIntelligenceSheetState();
}

class _BetaFeedbackIntelligenceSheetState
    extends State<BetaFeedbackIntelligenceSheet> {
  BetaChatGptDifferenceAnswer? _chatGptAnswer;
  BetaDifferentiatorAnswer? _differentiatorAnswer;
  BetaWouldPayAnswer? _wouldPayAnswer;
  BetaMainConfusionBucket? _mainConfusion;
  BetaStrongestMomentBucket? _strongestMoment;
  bool _submitting = false;

  bool get _canSubmit =>
      _chatGptAnswer != null &&
      _differentiatorAnswer != null &&
      _wouldPayAnswer != null &&
      _mainConfusion != null &&
      _strongestMoment != null;

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() => _submitting = true);
    final chatGpt = _chatGptAnswer!;
    final differentiator = _differentiatorAnswer!;
    final wouldPay = _wouldPayAnswer!;
    final mainConfusion = _mainConfusion!;
    final strongestMoment = _strongestMoment!;
    await BetaFeedbackIntelligenceStore.saveSubmission(
      chatGptDifferenceAnswer: chatGpt,
      differentiatorAnswer: differentiator,
      wouldPayAnswer: wouldPay,
      mainConfusionBucket: mainConfusion,
      strongestMomentBucket: strongestMoment,
    );
    final state = BetaFeedbackIntelligenceStore.cached;
    BetaFeedbackIntelligenceAnalytics.submitted(
      source: widget.source,
      entryCount: widget.entryCount,
      reachedFirstProof: widget.reachedFirstProof,
      sawProBridge: state.hasSeenProEvidenceBridge,
      chatGptDifferenceAnswer: chatGpt,
      wouldPayAnswer: wouldPay,
      mainConfusionBucket: mainConfusion,
      strongestMomentBucket: strongestMoment,
    );
    if (!mounted) return;
    widget.onSubmitted?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);
    final questionStyle = ArchiveMobileTypography.listTitle(
      context,
    ).copyWith(fontSize: 16);

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
            key: const Key('beta_feedback_intelligence_sheet'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                BetaFeedbackIntelligenceCopy.sheetTitle,
                key: const Key('beta_feedback_intelligence_sheet_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.md),
              _QuestionSection(
                title: BetaFeedbackIntelligenceCopy.chatGptDifferenceQuestion,
                titleKey: const Key('beta_feedback_intelligence_q_chatgpt'),
                options: const [
                  (
                    BetaChatGptDifferenceAnswer.yes,
                    BetaFeedbackIntelligenceCopy.chatGptDifferenceYes,
                    'beta_feedback_intelligence_chatgpt_yes',
                  ),
                  (
                    BetaChatGptDifferenceAnswer.notSure,
                    BetaFeedbackIntelligenceCopy.chatGptDifferenceNotSure,
                    'beta_feedback_intelligence_chatgpt_not_sure',
                  ),
                  (
                    BetaChatGptDifferenceAnswer.no,
                    BetaFeedbackIntelligenceCopy.chatGptDifferenceNo,
                    'beta_feedback_intelligence_chatgpt_no',
                  ),
                ],
                selected: _chatGptAnswer,
                onSelected: (value) => setState(
                  () => _chatGptAnswer = value as BetaChatGptDifferenceAnswer?,
                ),
                questionStyle: questionStyle,
                bodyStyle: bodyStyle,
              ),
              _QuestionSection(
                title: BetaFeedbackIntelligenceCopy.differentiatorQuestion,
                titleKey: const Key(
                  'beta_feedback_intelligence_q_differentiator',
                ),
                options: const [
                  (
                    BetaDifferentiatorAnswer.showedRepeats,
                    BetaFeedbackIntelligenceCopy.differentiatorRepeats,
                    'beta_feedback_intelligence_diff_repeats',
                  ),
                  (
                    BetaDifferentiatorAnswer.showedChange,
                    BetaFeedbackIntelligenceCopy.differentiatorChange,
                    'beta_feedback_intelligence_diff_change',
                  ),
                  (
                    BetaDifferentiatorAnswer.rememberedOlderMoments,
                    BetaFeedbackIntelligenceCopy.differentiatorOlderMoments,
                    'beta_feedback_intelligence_diff_older',
                  ),
                  (
                    BetaDifferentiatorAnswer.didNotFeelDifferent,
                    BetaFeedbackIntelligenceCopy.differentiatorNotDifferent,
                    'beta_feedback_intelligence_diff_not_different',
                  ),
                  (
                    BetaDifferentiatorAnswer.other,
                    BetaFeedbackIntelligenceCopy.differentiatorOther,
                    'beta_feedback_intelligence_diff_other',
                  ),
                ],
                selected: _differentiatorAnswer,
                onSelected: (value) => setState(
                  () => _differentiatorAnswer =
                      value as BetaDifferentiatorAnswer?,
                ),
                questionStyle: questionStyle,
                bodyStyle: bodyStyle,
              ),
              _QuestionSection(
                title: BetaFeedbackIntelligenceCopy.wouldPayQuestion,
                titleKey: const Key('beta_feedback_intelligence_q_would_pay'),
                options: const [
                  (
                    BetaWouldPayAnswer.yes,
                    BetaFeedbackIntelligenceCopy.wouldPayYes,
                    'beta_feedback_intelligence_pay_yes',
                  ),
                  (
                    BetaWouldPayAnswer.maybe,
                    BetaFeedbackIntelligenceCopy.wouldPayMaybe,
                    'beta_feedback_intelligence_pay_maybe',
                  ),
                  (
                    BetaWouldPayAnswer.no,
                    BetaFeedbackIntelligenceCopy.wouldPayNo,
                    'beta_feedback_intelligence_pay_no',
                  ),
                ],
                selected: _wouldPayAnswer,
                onSelected: (value) => setState(
                  () => _wouldPayAnswer = value as BetaWouldPayAnswer?,
                ),
                questionStyle: questionStyle,
                bodyStyle: bodyStyle,
              ),
              _QuestionSection(
                title: BetaFeedbackIntelligenceCopy.mainConfusionQuestion,
                titleKey: const Key('beta_feedback_intelligence_q_confusion'),
                options: const [
                  (
                    BetaMainConfusionBucket.firstRecording,
                    BetaFeedbackIntelligenceCopy.confusionFirstRecording,
                    'beta_feedback_intelligence_confusion_recording',
                  ),
                  (
                    BetaMainConfusionBucket.firstProof,
                    BetaFeedbackIntelligenceCopy.confusionFirstProof,
                    'beta_feedback_intelligence_confusion_proof',
                  ),
                  (
                    BetaMainConfusionBucket.patterns,
                    BetaFeedbackIntelligenceCopy.confusionPatterns,
                    'beta_feedback_intelligence_confusion_patterns',
                  ),
                  (
                    BetaMainConfusionBucket.pro,
                    BetaFeedbackIntelligenceCopy.confusionPro,
                    'beta_feedback_intelligence_confusion_pro',
                  ),
                  (
                    BetaMainConfusionBucket.differenceFromChatGpt,
                    BetaFeedbackIntelligenceCopy.confusionDifferenceFromChatGpt,
                    'beta_feedback_intelligence_confusion_chatgpt',
                  ),
                  (
                    BetaMainConfusionBucket.nothing,
                    BetaFeedbackIntelligenceCopy.confusionNothing,
                    'beta_feedback_intelligence_confusion_nothing',
                  ),
                ],
                selected: _mainConfusion,
                onSelected: (value) => setState(
                  () => _mainConfusion = value as BetaMainConfusionBucket?,
                ),
                questionStyle: questionStyle,
                bodyStyle: bodyStyle,
              ),
              _QuestionSection(
                title: BetaFeedbackIntelligenceCopy.strongestMomentQuestion,
                titleKey: const Key('beta_feedback_intelligence_q_strongest'),
                options: const [
                  (
                    BetaStrongestMomentBucket.firstProof,
                    BetaFeedbackIntelligenceCopy.strongestFirstProof,
                    'beta_feedback_intelligence_strongest_proof',
                  ),
                  (
                    BetaStrongestMomentBucket.whatChanged,
                    BetaFeedbackIntelligenceCopy.strongestWhatChanged,
                    'beta_feedback_intelligence_strongest_changed',
                  ),
                  (
                    BetaStrongestMomentBucket.quietSignal,
                    BetaFeedbackIntelligenceCopy.strongestQuietSignal,
                    'beta_feedback_intelligence_strongest_quiet',
                  ),
                  (
                    BetaStrongestMomentBucket.privateReport,
                    BetaFeedbackIntelligenceCopy.strongestPrivateReport,
                    'beta_feedback_intelligence_strongest_report',
                  ),
                  (
                    BetaStrongestMomentBucket.proExplanation,
                    BetaFeedbackIntelligenceCopy.strongestProExplanation,
                    'beta_feedback_intelligence_strongest_pro',
                  ),
                  (
                    BetaStrongestMomentBucket.nothingYet,
                    BetaFeedbackIntelligenceCopy.strongestNothingYet,
                    'beta_feedback_intelligence_strongest_nothing',
                  ),
                ],
                selected: _strongestMoment,
                onSelected: (value) => setState(
                  () => _strongestMoment = value as BetaStrongestMomentBucket?,
                ),
                questionStyle: questionStyle,
                bodyStyle: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                key: const Key('beta_feedback_intelligence_submit'),
                onPressed: _canSubmit && !_submitting ? _submit : null,
                child: const Text(BetaFeedbackIntelligenceCopy.submitCta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionSection extends StatelessWidget {
  const _QuestionSection({
    required this.title,
    required this.titleKey,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.questionStyle,
    required this.bodyStyle,
  });

  final String title;
  final Key titleKey;
  final List<(Enum, String, String)> options;
  final Enum? selected;
  final ValueChanged<Enum?> onSelected;
  final TextStyle questionStyle;
  final TextStyle bodyStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, key: titleKey, style: questionStyle),
          const SizedBox(height: AppSpacing.xs),
          for (final (value, label, keyName) in options)
            RadioListTile<Enum>(
              key: Key(keyName),
              title: Text(label, style: bodyStyle),
              value: value,
              groupValue: selected,
              onChanged: onSelected,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
        ],
      ),
    );
  }
}