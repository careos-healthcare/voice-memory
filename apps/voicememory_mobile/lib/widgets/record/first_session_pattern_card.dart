import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../features/feedback/archive_feedback_model.dart';
import '../../features/tomorrow_return/compelling_check_engine.dart';
import '../../features/tomorrow_return/compelling_check_model.dart';
import '../../features/tomorrow_return/watch_for_prompt_engine.dart';
import '../../features/tomorrow_return/watch_for_prompt_model.dart';
import '../../features/trial/hook_rescue_decision_model.dart';
import '../../features/first_session/first_session_coordinator.dart';
import '../../features/first_session/first_session_pattern_engine.dart';
import '../../features/first_session/first_session_pattern_model.dart';
import '../../features/first_session/pattern_correction_learning_coordinator.dart';
import '../../features/language/localized_copy.dart';
import '../../features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import '../tomorrow_return/compelling_check_preview.dart';
import '../feedback/archive_feedback_chips.dart';
import '../trial/check_in_worth_rating_prompt.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Post-save card for the first saved reflection — named pattern + tomorrow watch-for.
class FirstSessionPatternCard extends StatefulWidget {
  const FirstSessionPatternCard({
    super.key,
    required this.pattern,
    this.reflectionText = '',
    this.onPatternChanged,
    this.onAccept,
    this.onAddAnotherMoment,
    this.weakInput = false,
    this.sharperIntensity = HookRescueIntensity.normal,
    this.languageCode = 'en',
    this.feedbackHint,
  });

  final FirstSessionPattern pattern;

  /// The dominant feedback correction so far. "Not me" gently emphasizes the
  /// correction CTA so it is easier to fix the pattern.
  final ArchiveFeedbackType? feedbackHint;

  /// Detected/selected reflection language. Non-English localizes the
  /// surrounding guidance/buttons and the category title; English is unchanged.
  final String languageCode;

  /// True when the saved reflection was vague/too short. Shows an honest
  /// "Early read" label and offers adding another moment first.
  final bool weakInput;

  /// Called when the user chooses to add another moment instead of accepting.
  final VoidCallback? onAddAnotherMoment;

  /// Gated by diagnosis: how hard to push the sharper question.
  /// - normal: standard chooser
  /// - elevated: default to sharper for emotional categories
  /// - aggressive: sharper shown first, labelled "Best question"
  final HookRescueIntensity sharperIntensity;

  /// Full reflection text for correction learning (transcript preferred).
  final String reflectionText;

  final ValueChanged<FirstSessionPattern>? onPatternChanged;

  /// Test hook; defaults to [FirstSessionCoordinator.acceptForTomorrow].
  final Future<void> Function(
    FirstSessionPattern pattern, {
    String? correctionLearningId,
    String? reflectionText,
    String? sourceReflectionId,
    String? selectedVariantId,
    String? checkInQuestionOverride,
  })?
  onAccept;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFF5E6D3);

  @override
  State<FirstSessionPatternCard> createState() =>
      _FirstSessionPatternCardState();
}

class _FirstSessionPatternCardState extends State<FirstSessionPatternCard> {
  static const _engine = FirstSessionPatternEngine();
  static const _watchForPromptEngine = WatchForPromptEngine();

  late FirstSessionPattern _selected;
  late final FirstSessionPattern _original;
  bool _accepted = false;
  bool _saving = false;
  String? _checkInIdForRating;
  bool _questionRated = false;
  bool _showCorrectionLearned = false;
  String? _lastCorrectionLearningId;
  String? _selectedVariantId;
  String? _selectedSharpnessLabel;
  bool _variantShownTracked = false;
  bool _sharperShownTracked = false;
  bool _showOriginal = false;
  bool _showSharpenChooser = false;

  bool get _sharper => widget.sharperIntensity != HookRescueIntensity.normal;
  bool get _aggressive =>
      widget.sharperIntensity == HookRescueIntensity.aggressive;

  /// Weak input or low confidence both keep this an honest early read.
  bool get _earlyRead => widget.weakInput || _selected.isLowConfidence;

  /// English keeps the existing constant; other languages use localized copy.
  String _t(String key, String enValue) => widget.languageCode == 'en'
      ? enValue
      : localized(key, widget.languageCode);

  /// Localized category title for non-English; English keeps the engine title.
  String get _displayTitle =>
      localizedCategoryTitle(_selected.categoryId, widget.languageCode) ??
      _selected.title;

  @override
  void initState() {
    super.initState();
    _selected = widget.pattern;
    _original = widget.pattern;
    _selectedVariantId = _defaultVariantForFeedback();
    _selectedSharpnessLabel = defaultCompellingSharpnessLabel(
      feedback: widget.feedbackHint,
      preferDirect: widget.sharperIntensity != HookRescueIntensity.normal,
    );
    _trackWatchForPromptShown();
    unawaited(ActivationTracker.trackFirstPatternShown());
    ActivationTracker.trackActivationTomorrowCheckShown();
  }

  /// When feedback says too generic or not me, default chooser sharpness.
  String? _defaultVariantForFeedback() {
    if (widget.feedbackHint == ArchiveFeedbackType.tooGeneric ||
        widget.feedbackHint == ArchiveFeedbackType.moreSpecific) {
      return WatchForQuestionVariantId.practical;
    }
    if (widget.feedbackHint == ArchiveFeedbackType.notMe) {
      return WatchForQuestionVariantId.sharper;
    }
    if (widget.sharperIntensity != HookRescueIntensity.normal) {
      return WatchForQuestionVariantId.sharper;
    }
    return null;
  }

  String get _baseCheckQuestion => _effectiveCheckQuestion(_tomorrowPrompt);

  Map<String, CompellingCheckQuestion> get _compellingOptions =>
      buildCompellingCheckOptions(
        baseQuestion: _baseCheckQuestion,
        patternTitle: _displayTitle,
        feedback: widget.feedbackHint,
        preferDirect: widget.sharperIntensity != HookRescueIntensity.normal,
      );

  CompellingCheckQuestion get _selectedCompellingCheck {
    final label =
        _selectedSharpnessLabel ??
        defaultCompellingSharpnessLabel(
          feedback: widget.feedbackHint,
          preferDirect: widget.sharperIntensity != HookRescueIntensity.normal,
        );
    return _compellingOptions[label] ??
        buildCompellingCheck(
          baseQuestion: _baseCheckQuestion,
          patternTitle: _displayTitle,
          feedback: widget.feedbackHint,
          preferDirect: widget.sharperIntensity != HookRescueIntensity.normal,
          sharpnessLabel: label,
        );
  }

  void _onCompellingSharpnessSelected(CompellingCheckQuestion option) {
    setState(() => _selectedSharpnessLabel = option.sharpnessLabel);
    ActivationTracker.trackActivationTomorrowCheckSharpened();
  }

  void _trackVariantShownOnce(WatchForPrompt prompt) {
    if (_variantShownTracked || prompt.questionVariants.isEmpty) return;
    _variantShownTracked = true;
    ActivationTracker.trackTomorrowQuestionVariantShown(
      variantId: _effectiveVariantId(prompt),
      categoryId: _selected.categoryId,
    );
  }

  String _effectiveVariantId(WatchForPrompt prompt) =>
      _selectedVariantId ??
      prompt.selectedVariantId ??
      (prompt.questionVariants.isNotEmpty
          ? prompt.questionVariants.first.id
          : '');

  void _trackWatchForPromptShown() {
    final prompt = _watchForPromptEngine.build(
      pattern: _selected,
      reflectionText: widget.reflectionText,
    );
    unawaited(
      ActivationTracker.trackWatchForPromptShown(strength: prompt.strength.id),
    );
  }

  @override
  void didUpdateWidget(FirstSessionPatternCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pattern.id != widget.pattern.id) {
      _selected = widget.pattern;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chips = _selected.chips.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FirstSessionPatternCard._warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: FirstSessionPatternCard._warmBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _accepted ? _acceptedContent() : _promptContent(chips),
    );
  }

  Widget _acceptedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                ConsumerUiCopy.firstSessionSavedLine1,
                style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                  fontSize: 17,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          ConsumerUiCopy.firstSessionSavedLine2,
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ).copyWith(height: 1.45),
        ),
        if (_checkInIdForRating != null && !_questionRated)
          CheckInWorthRatingPrompt(
            checkInId: _checkInIdForRating!,
            onRated: () => setState(() => _questionRated = true),
          ),
      ],
    );
  }

  String get _headline {
    if (_selected.isLowConfidence || _selected.categoryId == 'fallback') {
      return ConsumerUiCopy.firstSessionPatternHeadlineLow;
    }
    return ConsumerUiCopy.firstSessionPatternHeadline;
  }

  WatchForPrompt get _tomorrowPrompt => _watchForPromptEngine.build(
    pattern: _selected,
    reflectionText: widget.reflectionText,
    intensity: widget.sharperIntensity,
  );

  void _onVariantSelected(String variantId, String categoryId) {
    if (_selectedVariantId == variantId) return;
    setState(() => _selectedVariantId = variantId);
    ActivationTracker.trackTomorrowQuestionVariantSelected(
      variantId: variantId,
      categoryId: categoryId,
    );
    ActivationTracker.trackActivationTomorrowCheckSharpened();
  }

  Widget _questionVariantChooser(WatchForPrompt tomorrow) {
    if (!_showSharpenChooser) return const SizedBox.shrink();
    _trackVariantShownOnce(tomorrow);
    if (_sharper && !_sharperShownTracked) {
      _sharperShownTracked = true;
      ActivationTracker.trackSharperQuestionShown();
      if (_aggressive) {
        ActivationTracker.trackSharperQuestionAggressiveShown();
      } else {
        ActivationTracker.trackSharperQuestionElevatedShown();
      }
    }
    final effectiveId = _effectiveVariantId(tomorrow);
    final selected = tomorrow.questionVariants.firstWhere(
      (v) => v.id == effectiveId,
      orElse: () => tomorrow.questionVariants.first,
    );

    // aggressive: show the sharper question first.
    final variants = List<WatchForQuestionVariant>.of(
      tomorrow.questionVariants,
    );
    if (_aggressive) {
      variants.sort((a, b) {
        if (a.id == WatchForQuestionVariantId.sharper) return -1;
        if (b.id == WatchForQuestionVariantId.sharper) return 1;
        return 0;
      });
    }

    final helper = _aggressive
        ? ConsumerUiCopy.chooseSharperQuestionHelperAggressive
        : ConsumerUiCopy.chooseSharperQuestionHelper;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          ConsumerUiCopy.chooseTomorrowQuestionLabel,
          style: VoiceMemoryTypography.metadataStyle(
            color: AppColors.textSecondary,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        if (_sharper) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            helper,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 13, height: 1.4),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final variant in variants)
              ChoiceChip(
                label: Text(_variantLabel(variant)),
                selected: variant.id == effectiveId,
                showCheckmark: false,
                onSelected: _saving
                    ? null
                    : (_) =>
                          _onVariantSelected(variant.id, _selected.categoryId),
                backgroundColor: Colors.white,
                selectedColor: AppColors.accentPrimary.withValues(alpha: 0.15),
                side: BorderSide(
                  color: variant.id == effectiveId
                      ? AppColors.accentPrimary
                      : const Color(0xFFF5E6D3),
                ),
                labelStyle:
                    VoiceMemoryTypography.bodyStyle(
                      color: variant.id == effectiveId
                          ? AppColors.accentPrimary
                          : AppColors.textSecondary,
                    ).copyWith(
                      fontSize: 13,
                      fontWeight: variant.id == effectiveId
                          ? FontWeight.w600
                          : null,
                    ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          selected.question,
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textPrimary,
          ).copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
        ),
      ],
    );
  }

  String _variantLabel(WatchForQuestionVariant variant) {
    if (_aggressive && variant.id == WatchForQuestionVariantId.sharper) {
      return ConsumerUiCopy.bestQuestionLabel;
    }
    return variant.label;
  }

  Widget _promptContent(List<String> chips) {
    final ambiguous = _selected.isAmbiguousMatch;
    final tomorrow = _tomorrowPrompt;
    final promptChips = tomorrow.chips.isNotEmpty ? tomorrow.chips : chips;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ConsumerUiCopy.firstSessionPatternLabel,
          style: VoiceMemoryTypography.metadataStyle(
            color: AppColors.accentPrimary,
          ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.6),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _headline,
          style: VoiceMemoryTypography.cardTitleStyle().copyWith(
            fontSize: 18,
            height: 1.35,
          ),
        ),
        if (_earlyRead) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: FirstSessionPatternCard._warmBorder),
            ),
            child: Text(
              _t('earlyRead', ConsumerUiCopy.inputQualityEarlyReadLabel),
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _t(
              'firstPatternEarlyReadHint',
              ConsumerUiCopy.firstPatternEarlyReadHint,
            ),
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 13, height: 1.4),
          ),
        ],
        if (ambiguous) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            ConsumerUiCopy.firstSessionAmbiguousHint,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          _displayTitle,
          style: VoiceMemoryTypography.cardTitleStyle().copyWith(
            fontSize: 20,
            height: 1.3,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _selected.noticedBecauseLine,
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ).copyWith(fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _selected.whyNoticed,
          style: VoiceMemoryTypography.bodyStyle().copyWith(height: 1.45),
        ),
        _buildShowOriginal(),
        const SizedBox(height: AppSpacing.md),
        Text(
          ConsumerUiCopy.firstSessionWatchTomorrowSection,
          style: VoiceMemoryTypography.metadataStyle(
            color: AppColors.textSecondary,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        CompellingCheckPreview(
          check: _selectedCompellingCheck,
          options: _showSharpenChooser ? _compellingOptions : null,
          selectedSharpnessLabel: _selectedSharpnessLabel,
          onSharpnessSelected: _saving ? null : _onCompellingSharpnessSelected,
        ),
        if (!_showSharpenChooser) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _saving ? null : _onMakeItSharper,
              child: Text(_t('makeItSharper', ConsumerUiCopy.makeItSharperCta)),
            ),
          ),
        ],
        if (promptChips.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: promptChips
                .map(
                  (c) => Chip(
                    label: Text(c),
                    backgroundColor: AppColors.backgroundSecondary,
                    side: BorderSide(
                      color: FirstSessionPatternCard._warmBorder,
                    ),
                    labelStyle: VoiceMemoryTypography.bodyStyle(
                      color: AppColors.textSecondary,
                    ).copyWith(fontSize: 13),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (widget.weakInput && widget.onAddAnotherMoment != null) ...[
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: _saving ? null : widget.onAddAnotherMoment,
              child: Text(
                _t(
                  'addAnotherMoment',
                  ConsumerUiCopy.firstPatternAddAnotherMomentCta,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: _saving ? null : _onAccept,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _t(
                        'useThisTomorrow',
                        ConsumerUiCopy.firstSessionUseTomorrowCta,
                      ),
                    ),
            ),
          ),
        ] else
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: _saving ? null : _onAccept,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _t(
                        'useThisTomorrow',
                        ConsumerUiCopy.firstSessionUseTomorrowCta,
                      ),
                    ),
            ),
          ),
        if (_showCorrectionLearned) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            ConsumerUiCopy.firstSessionCorrectionLearnedLine,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.success,
            ).copyWith(fontSize: 13, height: 1.4),
          ),
        ],
        if (_selected.userCanCorrect) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: _saving
                  ? null
                  : () => unawaited(_openCorrectionPicker()),
              child: Text(
                ambiguous
                    ? ConsumerUiCopy.firstSessionChooseCloserCta
                    : ConsumerUiCopy.firstSessionNotQuiteCta,
                style: TextStyle(
                  // "Not me" feedback nudges the correction CTA to stand out.
                  fontWeight:
                      (ambiguous ||
                          widget.feedbackHint == ArchiveFeedbackType.notMe)
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
        ArchiveFeedbackChips(
          targetType: ArchiveFeedbackTargetType.firstPattern,
          targetId: _selected.id,
          patternTitle: _selected.title,
          languageCode: widget.languageCode,
        ),
      ],
    );
  }

  /// Quiet "Show original" toggle revealing the preserved original reflection
  /// text. The original is never translated.
  Widget _buildShowOriginal() {
    final original = widget.reflectionText.trim();
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
                  ? _t('hideOriginal', 'Hide original')
                  : _t('showOriginal', 'Show original'),
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
              border: Border.all(color: FirstSessionPatternCard._warmBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('originalLabel', 'Original'),
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

  Future<void> _openCorrectionPicker() async {
    final options = <_PickerOption>[
      _PickerOption(
        label: _original.title,
        pattern: _original,
        isCorrection: false,
      ),
      ..._original.alternativePatterns.map(
        (alt) => _PickerOption(
          label: alt.title,
          pattern: _original.withAlternative(alt),
          isCorrection: true,
        ),
      ),
      _PickerOption(
        label: ConsumerUiCopy.firstSessionSomethingElse,
        pattern: _original.withAlternative(_engine.fallbackAlternative()),
        isCorrection: true,
      ),
    ];

    final picked = await showModalBottomSheet<_PickerOption>(
      context: context,
      backgroundColor: AppColors.backgroundPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ConsumerUiCopy.firstSessionWhichCloserTitle,
                  style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final opt in options)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(opt.label),
                    subtitle: opt.pattern.watchForText.isNotEmpty
                        ? Text(
                            opt.pattern.watchForText,
                            style: VoiceMemoryTypography.bodyStyle(
                              color: AppColors.textSecondary,
                            ).copyWith(fontSize: 13),
                          )
                        : null,
                    onTap: () => Navigator.pop(ctx, opt),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null || !mounted) return;

    final wasCorrection =
        picked.isCorrection && picked.pattern.title != _original.title;
    setState(() {
      _selected = picked.pattern;
      _selectedVariantId = null;
      _variantShownTracked = false;
    });
    widget.onPatternChanged?.call(_selected);

    if (wasCorrection) {
      final reflection = widget.reflectionText.trim().isNotEmpty
          ? widget.reflectionText
          : _selected.sourceTextPreview;
      final learning =
          await PatternCorrectionLearningCoordinator.recordFirstSessionCorrection(
            originalPattern: _original,
            correctedPattern: _selected,
            reflectionText: reflection,
          );
      if (!mounted) return;
      setState(() {
        _lastCorrectionLearningId = learning.id;
        _showCorrectionLearned = true;
      });
      _trackWatchForPromptShown();
      unawaited(
        ActivationTracker.trackFirstPatternCorrected(
          originalTitle: _original.title,
          selectedTitle: _selected.title,
          confidenceScore: _original.confidenceScore,
        ),
      );
    }
  }

  String _effectiveCheckQuestion(WatchForPrompt tomorrow) {
    if (tomorrow.questionVariants.isEmpty) {
      return tomorrow.checkInQuestion;
    }
    final effectiveId = _effectiveVariantId(tomorrow);
    final selected = tomorrow.questionVariants.firstWhere(
      (v) => v.id == effectiveId,
      orElse: () => tomorrow.questionVariants.first,
    );
    return selected.question;
  }

  void _onMakeItSharper() {
    setState(() => _showSharpenChooser = true);
    ActivationTracker.trackActivationTomorrowCheckSharpened();
  }

  Future<void> _onAccept() async {
    setState(() => _saving = true);
    ActivationTracker.trackActivationTomorrowCheckUsed();
    ActivationTracker.trackCompellingCheckAccepted();
    final acceptedVariantId =
        _selectedVariantId ?? _tomorrowPrompt.selectedVariantId;
    if (_sharper && acceptedVariantId == WatchForQuestionVariantId.sharper) {
      ActivationTracker.trackSharperQuestionAccepted();
      if (_aggressive) {
        ActivationTracker.trackSharperQuestionAggressiveAccepted();
      }
    }
    try {
      final reflection = widget.reflectionText.trim().isNotEmpty
          ? widget.reflectionText
          : _selected.sourceTextPreview;
      final accept =
          widget.onAccept ??
          (
            pattern, {
            correctionLearningId,
            reflectionText,
            sourceReflectionId,
            selectedVariantId,
            checkInQuestionOverride,
          }) => FirstSessionCoordinator.acceptForTomorrow(
            pattern,
            correctionLearningId: correctionLearningId,
            reflectionText: reflectionText ?? '',
            sourceReflectionId: sourceReflectionId,
            selectedVariantId: selectedVariantId,
            checkInQuestionOverride: checkInQuestionOverride,
          );
      await accept(
        _selected,
        correctionLearningId: _lastCorrectionLearningId,
        reflectionText: reflection,
        sourceReflectionId: null,
        selectedVariantId: acceptedVariantId,
        checkInQuestionOverride: _selectedCompellingCheck.question,
      );
      if (!mounted) return;
      final active = await TomorrowCheckInCoordinator.loadActive();
      setState(() {
        _accepted = true;
        _saving = false;
        _checkInIdForRating = active?.id;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }
}

class _PickerOption {
  const _PickerOption({
    required this.label,
    required this.pattern,
    required this.isCorrection,
  });

  final String label;
  final FirstSessionPattern pattern;
  final bool isCorrection;
}
