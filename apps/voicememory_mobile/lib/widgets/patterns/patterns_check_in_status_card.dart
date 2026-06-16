import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/activation/activation_tracker.dart';
import '../../features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import '../../features/tomorrow_return/tomorrow_check_in_model.dart';
import '../../features/tomorrow_return/useful_result_takeaway_engine.dart';
import '../../features/tomorrow_return/useful_result_takeaway_model.dart';
import '../../features/trial/hook_rescue_decision_model.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Patterns top: due check-in waiting or loop recently closed.
class PatternsCheckInStatusCard extends StatelessWidget {
  const PatternsCheckInStatusCard.waiting({super.key, this.question})
    : completed = null,
      due = true,
      betterResultIntensity = HookRescueIntensity.normal,
      notUsefulReason = null,
      onUseCheck = null;

  const PatternsCheckInStatusCard.closed({
    super.key,
    required this.completed,
    this.betterResultIntensity = HookRescueIntensity.normal,
    this.notUsefulReason,
    this.onUseCheck,
  }) : due = false,
       question = null;

  final bool due;
  final TomorrowCheckIn? completed;

  /// Creates tomorrow's check-in for [question] from the Patterns tab.
  /// Defaults to the coordinator; injectable so widget tests skip storage.
  final Future<void> Function(String question)? onUseCheck;

  /// Yesterday's question, surfaced on the waiting card so the user sees exactly
  /// what to answer before tapping through.
  final String? question;

  /// Gated by diagnosis: escalate the result interpretation.
  final HookRescueIntensity betterResultIntensity;
  final String? notUsefulReason;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFF5E6D3);

  @override
  Widget build(BuildContext context) {
    if (due) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: _warmSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.accentPrimary.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ConsumerUiCopy.patternsCheckInWaitingTitle,
              style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                fontSize: 17,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              ConsumerUiCopy.patternsCheckInWaitingBody,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(height: 1.45),
            ),
            if (question != null && question!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                question!,
                style:
                    VoiceMemoryTypography.bodyStyle(
                      color: AppColors.textPrimary,
                    ).copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: () => context.go('/record'),
                child: const Text(ConsumerUiCopy.patternsCheckInWaitingCta),
              ),
            ),
          ],
        ),
      );
    }

    final checkIn = completed;
    if (checkIn == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsumerUiCopy.patternsLoopClosedTitle,
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.success,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            checkIn.resultHeadline,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _takeaway(checkIn).headline,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 14, fontWeight: FontWeight.w700, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _takeaway(checkIn).whyUseful,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(height: 1.45, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            ConsumerUiCopy.resultNextCheckTitle,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _takeaway(checkIn).nextCheck,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          _PatternsUseCheckButton(
            question: _takeaway(checkIn).nextCheck,
            patternTitle: checkIn.patternTitle,
            specificPrompt: checkIn.prompt,
            onUseCheck: onUseCheck,
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.go('/record'),
              child: const Text(ConsumerUiCopy.patternsRecordAnotherMomentCta),
            ),
          ),
        ],
      ),
    );
  }

  UsefulResultTakeaway _takeaway(TomorrowCheckIn checkIn) =>
      buildUsefulResultTakeaway(
        resultHint: checkIn.selectedOptionId ?? 'same',
        checkInQuestion: checkIn.question,
        reflectionText: null,
        notUsefulReason: notUsefulReason,
      );
}

/// Compact "Use this check" CTA for the Patterns loop-closed card. Creates
/// tomorrow's check-in and confirms inline so the user gets a clear next step.
class _PatternsUseCheckButton extends StatefulWidget {
  const _PatternsUseCheckButton({
    required this.question,
    required this.patternTitle,
    required this.specificPrompt,
    this.onUseCheck,
  });

  final String question;
  final String patternTitle;
  final String specificPrompt;
  final Future<void> Function(String question)? onUseCheck;

  @override
  State<_PatternsUseCheckButton> createState() =>
      _PatternsUseCheckButtonState();
}

class _PatternsUseCheckButtonState extends State<_PatternsUseCheckButton> {
  bool _busy = false;
  bool _done = false;

  Future<void> _onTap() async {
    if (_busy || _done) return;
    setState(() => _busy = true);
    ActivationTracker.trackResultNextCheckUsedFromPatterns();
    ActivationTracker.trackUsefulResultNextCheckUsed();
    final create = widget.onUseCheck ?? _defaultCreate;
    await create(widget.question);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = true;
    });
  }

  Future<void> _defaultCreate(String question) async {
    await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: widget.patternTitle,
      specificPrompt: widget.specificPrompt,
      checkInQuestion: question,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              ConsumerUiCopy.resultNextCheckConfirmation,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.success,
              ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: FilledButton(
        onPressed: _busy ? null : _onTap,
        child: const Text(ConsumerUiCopy.patternsResultUseCheckCta),
      ),
    );
  }
}
