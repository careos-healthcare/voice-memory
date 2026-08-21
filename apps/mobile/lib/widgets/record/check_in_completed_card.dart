import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/feedback/archive_feedback_model.dart';
import 'package:archiveme_mobile/features/language/localized_copy.dart';
import 'package:archiveme_mobile/features/tomorrow_return/check_in_result_interpretation.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/useful_result_takeaway_engine.dart';
import 'package:archiveme_mobile/features/tomorrow_return/useful_result_takeaway_model.dart';
import 'package:archiveme_mobile/features/trial/hook_rescue_decision_model.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/feedback/archive_feedback_chips.dart';
import 'package:archiveme_mobile/widgets/record/make_result_more_useful_sheet.dart';
import 'package:archiveme_mobile/widgets/trial/check_in_result_rating_prompt.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Post-save confirmation after completing a due tomorrow check-in.
class CheckInCompletedCard extends StatefulWidget {
  const CheckInCompletedCard({
    required this.checkIn, super.key,
    this.showBetterResult = false,
    this.betterResultIntensity = HookRescueIntensity.normal,
    this.notUsefulReason,
    this.nextCheckSlot,
    this.weakInput = false,
    this.languageCode = 'en',
    this.originalText,
  });

  final TomorrowCheckIn checkIn;

  /// The user's preserved original reflection text. Never translated. When set,
  /// a quiet "Show original" toggle reveals it for non-English reflections.
  final String? originalText;

  /// Detected/selected reflection language. Non-English localizes the takeaway
  /// labels, buttons, and result copy; English is unchanged.
  final String languageCode;

  /// True when the saved reflection was vague/too short. Keeps the result an
  /// "Early read" and points the next check at one concrete moment.
  final bool weakInput;

  /// Optional "Next useful check" card rendered just above the usefulness
  /// rating, so people choose the next check before rating the result. When
  /// provided, it replaces the lighter "tomorrow's better question" hint.
  final Widget? nextCheckSlot;

  /// Gated by diagnosis: when people return but say the result is not useful,
  /// add a "Why this is useful" section.
  final bool showBetterResult;

  /// Escalation level for the better-result section.
  /// - elevated: "Why this is useful"
  /// - aggressive: also adds "Try this next"
  final HookRescueIntensity betterResultIntensity;

  /// Most recent "not useful" complaint, used to tailor the extra section.
  final String? notUsefulReason;

  @override
  State<CheckInCompletedCard> createState() => _CheckInCompletedCardState();
}

class _CheckInCompletedCardState extends State<CheckInCompletedCard> {
  bool _resultRated = false;
  bool _goDeeperExpanded = false;
  bool _showOriginal = false;

  /// Set when the user refines the result via "Make this more useful". Takes
  /// precedence over the diagnosis-provided [widget.notUsefulReason].
  String? _moreUsefulReason;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = AppColors.warmBorder;

  String? get _effectiveReason => _moreUsefulReason ?? widget.notUsefulReason;

  /// English keeps the existing constant; other languages use localized copy.
  String _label(String key, String enValue) => widget.languageCode == 'en'
      ? enValue
      : localized(key, widget.languageCode);

  UsefulResultTakeaway get _takeaway => buildUsefulResultTakeaway(
    resultHint: widget.checkIn.selectedOptionId ?? 'same',
    checkInQuestion: widget.checkIn.question,
    notUsefulReason: _effectiveReason,
    inputQualityWeak: widget.weakInput,
    languageCode: widget.languageCode,
  );

  HookRescueIntensity get _intensity {
    if (widget.betterResultIntensity != HookRescueIntensity.normal) {
      return widget.betterResultIntensity;
    }
    return widget.showBetterResult
        ? HookRescueIntensity.elevated
        : HookRescueIntensity.normal;
  }

  bool get _showWhy => _intensity != HookRescueIntensity.normal;

  /// "Go deeper" is offered when the result is obvious (a plain repeat or one
  /// the preset answers did not capture) or already flagged weak by diagnosis.
  bool get _showGoDeeper {
    if (widget.nextCheckSlot != null) return false;
    final id = widget.checkIn.selectedOptionId;
    return id == 'showed_up_again' || id == 'none_fit' || _showWhy;
  }

  CheckInResultInterpretation get _interpretation =>
      buildCheckInResultInterpretation(
        resultHint: widget.checkIn.selectedOptionId ?? 'same',
        question: widget.checkIn.question,
        reflectionText: null,
        topNotUsefulReason: _effectiveReason,
      );

  @override
  void initState() {
    super.initState();
    ActivationTracker.trackUsefulResultTakeawayShown();
    unawaited(ActivationTracker.trackActivationUsefulTakeawayShown());
    if (_showWhy) {
      ActivationTracker.trackBetterResultShown();
      if (_intensity == HookRescueIntensity.aggressive) {
        ActivationTracker.trackBetterResultAggressiveShown();
      } else {
        ActivationTracker.trackBetterResultElevatedShown();
      }
    }
    if (_showGoDeeper) {
      ActivationTracker.trackCheckInGoDeeperShown();
    }
  }

  void _onGoDeeper() {
    ActivationTracker.trackCheckInGoDeeperTapped();
    setState(() => _goDeeperExpanded = true);
  }

  Future<void> _onMakeMoreUseful() async {
    await ActivationTracker.trackActivationMakeUsefulTapped();
    final reason = await MakeResultMoreUsefulSheet.show(context);
    if (reason == null || !mounted) return;
    await ActivationTracker.trackActivationMakeUsefulReasonSelected();
    setState(() => _moreUsefulReason = reason);
  }

  @override
  Widget build(BuildContext context) {
    final checkIn = widget.checkIn;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _warmBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _label('loopClosed', ConsumerUiCopy.checkInLoopClosedTitle),
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 17,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            localizedResultHeadline(
              checkIn.selectedOptionId,
              widget.languageCode,
            ),
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildTakeawaySection(_takeaway),
          _buildShowOriginal(),
          if (_showGoDeeper) ...[
            const SizedBox(height: AppSpacing.sm),
            if (!_goDeeperExpanded)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _onGoDeeper,
                  child: const Text(ConsumerUiCopy.checkInGoDeeperCta),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _warmBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ConsumerUiCopy.checkInGoDeeperTitle,
                      style: VoiceMemoryTypography.bodyStyle(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _interpretation.nextCheck,
                      style:
                          VoiceMemoryTypography.bodyStyle(
                            color: AppColors.textPrimary,
                          ).copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      ConsumerUiCopy.checkInGoDeeperHelper,
                      style: VoiceMemoryTypography.bodyStyle(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
          ],
          if (widget.nextCheckSlot != null) ...[
            const SizedBox(height: AppSpacing.md),
            widget.nextCheckSlot!,
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _onMakeMoreUseful,
              child: Text(
                _label(
                  'makeThisMoreUseful',
                  ConsumerUiCopy.makeResultMoreUsefulCta,
                ),
              ),
            ),
          ),
          // One feedback row at a time: the quick usefulness rating first, then
          // the sharper correction chips once it is answered.
          if (!_resultRated)
            CheckInResultRatingPrompt(
              checkInId: checkIn.id,
              onRated: () => setState(() => _resultRated = true),
            )
          else
            ArchiveFeedbackChips(
              targetType: ArchiveFeedbackTargetType.checkInResult,
              targetId: checkIn.id,
              patternTitle: checkIn.patternTitle,
              resultHint: checkIn.selectedOptionId,
              languageCode: widget.languageCode,
            ),
        ],
      ),
    );
  }

  /// Quiet "Show original" toggle that reveals the user's preserved original
  /// reflection text. The original is never translated.
  Widget _buildShowOriginal() {
    final original = widget.originalText?.trim() ?? '';
    if (original.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _showOriginal = !_showOriginal),
            child: Text(
              _showOriginal
                  ? _label('hideOriginal', 'Hide original')
                  : _label('showOriginal', 'Show original'),
            ),
          ),
        ),
        if (_showOriginal)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _warmBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label('originalLabel', 'Original'),
                  style: VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  original,
                  style: VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 14, height: 1.45),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Compact "Useful takeaway" section shown before the usefulness rating.
  ///
  /// When a [CheckInCompletedCard.nextCheckSlot] is present below, the next
  /// check and example live there, so the takeaway omits them to avoid showing
  /// the same next question twice.
  Widget _buildTakeawaySection(UsefulResultTakeaway takeaway) {
    final labelStyle = VoiceMemoryTypography.bodyStyle(
      color: AppColors.textSecondary,
    ).copyWith(fontSize: 12, fontWeight: FontWeight.w600);
    final bodyStyle = VoiceMemoryTypography.bodyStyle(
      color: AppColors.textPrimary,
    ).copyWith(fontSize: 14, height: 1.45);
    // The next check + example live in the takeaway only when neither the
    // result-next-check card nor the "go deeper" block will also show one.
    final showInlineNextCheck = widget.nextCheckSlot == null && !_showGoDeeper;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _label('usefulTakeaway', ConsumerUiCopy.usefulTakeawayTitle),
          style: labelStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          takeaway.headline,
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textPrimary,
          ).copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.35),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(_label('whatChanged', 'What changed'), style: labelStyle),
        const SizedBox(height: AppSpacing.xs),
        Text(takeaway.whatItMeans, style: bodyStyle),
        const SizedBox(height: AppSpacing.sm),
        Text(_label('whyUseful', 'Why this is useful'), style: labelStyle),
        const SizedBox(height: AppSpacing.xs),
        Text(takeaway.whyUseful, style: bodyStyle),
        if (takeaway.confidenceLabel != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _warmBorder),
            ),
            child: Text(
              takeaway.confidenceLabel!,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        if (showInlineNextCheck) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _label('nextCheck', ConsumerUiCopy.usefulTakeawayNextCheckLabel),
            style: labelStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            takeaway.nextCheck,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _warmBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label(
                    'exampleLabel',
                    ConsumerUiCopy.usefulTakeawayExampleLabel,
                  ),
                  style: labelStyle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(takeaway.example, style: bodyStyle),
              ],
            ),
          ),
        ],
      ],
    );
  }
}