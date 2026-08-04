import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/beta_proof_feedback/beta_proof_feedback_copy.dart';
import '../../features/beta_proof_feedback/beta_proof_feedback_model.dart';
import '../../features/beta_proof_feedback/beta_proof_feedback_store.dart';
import '../../features/first_session_proof_repair/first_session_proof_repair_engine.dart';
import '../../features/first_session_proof_repair/first_session_proof_repair_analytics.dart';
import '../../features/first_session_proof_repair/first_session_proof_repair_copy.dart';
import '../../features/first_session_proof_repair/first_session_proof_repair_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

class FirstSessionCaptureRepairCard extends StatefulWidget {
  const FirstSessionCaptureRepairCard({
    super.key,
    required this.result,
    required this.onTypeOneSentence,
    required this.onUseVoice,
    required this.onChipSelected,
  });

  const FirstSessionCaptureRepairCard.test({
    super.key,
    required this.result,
    required this.onTypeOneSentence,
    required this.onUseVoice,
    required this.onChipSelected,
  });

  final FirstSessionCaptureRepairResult result;
  final VoidCallback onTypeOneSentence;
  final VoidCallback onUseVoice;
  final ValueChanged<String> onChipSelected;

  @override
  State<FirstSessionCaptureRepairCard> createState() =>
      _FirstSessionCaptureRepairCardState();
}

class _FirstSessionCaptureRepairCardState
    extends State<FirstSessionCaptureRepairCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen || !widget.result.shouldShow) return;
    _trackedSeen = true;
    FirstSessionProofRepairAnalytics.captureSeen(result: widget.result);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.result.shouldShow) {
      return const SizedBox.shrink(
        key: Key('first_session_capture_repair_card_hidden'),
      );
    }

    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: const Key('first_session_capture_repair_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('first_session_capture_repair_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('first_session_capture_repair_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final chip in widget.result.chips)
                ActionChip(
                  key: Key(
                    'first_session_capture_repair_chip_'
                    '${FirstSessionProofRepairCopy.captureChipAnalyticsId(chip.id)}',
                  ),
                  label: Text(chip.text),
                  onPressed: () {
                    FirstSessionProofRepairAnalytics.captureChipTapped(
                      result: widget.result,
                      chipId: chip.id,
                    );
                    widget.onChipSelected(
                      FirstSessionProofRepairEngine.chipPromptFor(chip.text),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('first_session_capture_repair_primary_cta'),
            onPressed: () {
              FirstSessionProofRepairAnalytics.captureCtaTapped(
                result: widget.result,
                actionType: FirstSessionProofRepairActionType.typeOneSentence,
              );
              widget.onTypeOneSentence();
            },
            child: Text(widget.result.primaryCta),
          ),
          TextButton(
            key: const Key('first_session_capture_repair_secondary_cta'),
            onPressed: () {
              FirstSessionProofRepairAnalytics.captureCtaTapped(
                result: widget.result,
                actionType: FirstSessionProofRepairActionType.useVoice,
              );
              widget.onUseVoice();
            },
            child: Text(widget.result.secondaryCta),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.microcopy,
            key: const Key('first_session_capture_repair_microcopy'),
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}

class ProofQualityRepairCard extends StatefulWidget {
  const ProofQualityRepairCard({
    super.key,
    required this.result,
    this.onChanged,
    this.onNotRelevantAnswered,
    this.store,
    this.skipPrefsLoad = false,
    this.initialAnswered = false,
    this.initialAnswerType,
  });

  const ProofQualityRepairCard.test({
    super.key,
    required this.result,
    this.onChanged,
    this.onNotRelevantAnswered,
    this.store,
    bool answered = false,
    BetaProofFeedbackType? answerType,
  }) : skipPrefsLoad = true,
       initialAnswered = answered,
       initialAnswerType = answerType;

  final ProofQualityRepairResult result;
  final VoidCallback? onChanged;
  final Future<void> Function()? onNotRelevantAnswered;
  final BetaProofFeedbackStore? store;
  final bool skipPrefsLoad;
  final bool initialAnswered;
  final BetaProofFeedbackType? initialAnswerType;

  @override
  State<ProofQualityRepairCard> createState() => _ProofQualityRepairCardState();
}

class _ProofQualityRepairCardState extends State<ProofQualityRepairCard> {
  var _trackedSeen = false;
  var _answered = false;
  BetaProofFeedbackType? _answerType;

  @override
  void initState() {
    super.initState();
    if (widget.skipPrefsLoad) {
      _answered = widget.initialAnswered;
      _answerType = widget.initialAnswerType;
      return;
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    await BetaProofFeedbackStore.ensureLoaded();
    if (!mounted) return;
    final record = BetaProofFeedbackStore.recordFor(widget.result.surface);
    setState(() {
      _answered = BetaProofFeedbackStore.isAnsweredToday(widget.result.surface);
      _answerType = record.feedbackType;
    });
  }

  void _trackSeenOnce() {
    if (_trackedSeen || !widget.result.shouldShow || _answered) return;
    _trackedSeen = true;
    FirstSessionProofRepairAnalytics.proofSeen(result: widget.result);
  }

  Future<void> _selectAnswer(BetaProofFeedbackType feedbackType) async {
    final store = widget.store ?? BetaProofFeedbackStore.instance();
    await store.saveAnswer(
      surface: widget.result.surface,
      feedbackType: feedbackType,
      entryCount: widget.result.entryCount,
    );
    FirstSessionProofRepairAnalytics.proofAnswered(
      result: widget.result,
      answerType: feedbackType,
    );
    if (feedbackType == BetaProofFeedbackType.notRelevant) {
      await widget.onNotRelevantAnswered?.call();
    }
    if (!mounted) return;
    setState(() {
      _answered = true;
      _answerType = feedbackType;
    });
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.result.shouldShow) {
      return const SizedBox.shrink(
        key: Key('proof_quality_repair_card_hidden'),
      );
    }

    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: const Key('proof_quality_repair_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('proof_quality_repair_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('proof_quality_repair_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          if (_answered && _answerType != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              FirstSessionProofRepairCopy.proofNextStepFor(_answerType!),
              key: Key(
                'proof_quality_repair_next_step_${_answerType!.storageValue}',
              ),
              style: bodyStyle.copyWith(color: AppColors.textPrimary),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.result.cta,
              key: const Key('proof_quality_repair_cta'),
              style: ArchiveMobileTypography.cardLabel(context).copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final type in BetaProofFeedbackType.values)
                  TextButton(
                    key: Key(
                      'proof_quality_repair_option_${type.storageValue}',
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () => unawaited(_selectAnswer(type)),
                    child: Text(BetaProofFeedbackCopy.labelFor(type)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
