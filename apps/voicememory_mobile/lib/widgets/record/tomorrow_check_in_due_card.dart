import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../features/language/localized_copy.dart';
import '../../features/routine/routine_anchor_model.dart';
import '../../features/tomorrow_return/check_in_result_copy.dart';
import '../../features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import '../../features/tomorrow_return/tomorrow_check_in_model.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Dominant return-day card: answer yesterday's locked check-in, then record.
class TomorrowCheckInDueCard extends StatefulWidget {
  const TomorrowCheckInDueCard({
    super.key,
    required this.checkIn,
    this.onRecord,
    this.onSelectOption,
    this.guided = false,
    this.oneTapMode = false,
    this.languageCode = 'en',
    this.plannedAnchor,
  });

  final TomorrowCheckIn checkIn;

  /// The routine moment this check was attached to, shown as "Planned for: …".
  final RoutineAnchor? plannedAnchor;

  /// Detected/selected reflection language. Non-English localizes the record
  /// button; English is unchanged.
  final String languageCode;
  final VoidCallback? onRecord;
  final Future<void> Function(TomorrowCheckInOption option)? onSelectOption;

  /// Guided mode (gated by diagnosis when confusion is high): one step at a
  /// time, two primary answers first, lighter/heavier revealed second.
  final bool guided;

  /// Return-day fast path: yesterday's question plus four large answer buttons,
  /// no examples, and a single "record one sentence" step after answering.
  final bool oneTapMode;

  @override
  State<TomorrowCheckInDueCard> createState() => _TomorrowCheckInDueCardState();
}

class _TomorrowCheckInDueCardState extends State<TomorrowCheckInDueCard> {
  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFE8D4BC);
  static const Color _accentBorder = Color(0xFFD4A574);

  String? _selectedOptionId;
  bool _saving = false;
  bool _examplesExpanded = false;
  bool _clarityCardShownTracked = false;
  bool _guidedStarted = false;
  bool _guidedSecondaryRevealed = false;

  @override
  void initState() {
    super.initState();
    _selectedOptionId = widget.checkIn.selectedOptionId;
    _trackClarityCardShownOnce();
    if (widget.guided) {
      ActivationTracker.trackGuidedCheckInShown();
      if (_selectedOptionId != null) _guidedStarted = true;
    }
  }

  String _t(String key, String enValue) =>
      widget.languageCode == 'en' ? enValue : localized(key, widget.languageCode);

  String _optionLabel(TomorrowCheckInOption option) =>
      localizedOptionLabel(option.id, option.label, widget.languageCode);

  String _followUp(TomorrowCheckInOption option) => widget.languageCode == 'en'
      ? option.followUpPrompt
      : localizedCheckInQuestion(option.id, widget.languageCode);

  TomorrowCheckInOption? _optionById(String id) {
    for (final o in widget.checkIn.options) {
      if (o.id == id) return o;
    }
    return null;
  }

  void _trackClarityCardShownOnce() {
    if (_clarityCardShownTracked) return;
    _clarityCardShownTracked = true;
    ActivationTracker.trackCheckInClarityCardShown();
  }

  TomorrowCheckInOption? get _selected {
    final id = _selectedOptionId;
    if (id == null) return null;
    for (final o in widget.checkIn.options) {
      if (o.id == id) return o;
    }
    return null;
  }

  Future<void> _onOptionTap(TomorrowCheckInOption option) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final select = widget.onSelectOption ??
          (o) => TomorrowCheckInCoordinator.selectOption(
                checkInId: widget.checkIn.id,
                optionId: o.id,
              );
      await select(option);
      if (!mounted) return;
      setState(() {
        _selectedOptionId = option.id;
        _saving = false;
      });
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onRecord() {
    ActivationTracker.trackCheckInMomentRecorded();
    ActivationTracker.trackTomorrowCheckInRecordingStarted();
    (widget.onRecord ?? () {})();
  }

  void _toggleExamples() {
    final expanding = !_examplesExpanded;
    setState(() => _examplesExpanded = expanding);
    if (expanding) {
      ActivationTracker.trackCheckInExamplesOpened();
    }
  }

  void _onGuidedStart() {
    setState(() => _guidedStarted = true);
    ActivationTracker.trackGuidedCheckInStepCompleted();
  }

  List<Widget> _standardAnswerSection(List<TomorrowCheckInOption> options) {
    return [
      Text(
        _t('todayHappened', ConsumerUiCopy.tomorrowCheckInTodayHappenedLabel),
        style: VoiceMemoryTypography.bodyStyle(
          color: AppColors.textSecondary,
        ).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            _OptionChip(
              label: _optionLabel(option),
              selected: _selectedOptionId == option.id,
              onTap: _saving ? null : () => _onOptionTap(option),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      InkWell(
        onTap: _toggleExamples,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                _examplesExpanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                ConsumerUiCopy.tomorrowCheckInNeedExamples,
                style: VoiceMemoryTypography.bodyStyle(
                  color: AppColors.textSecondary,
                ).copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      if (_examplesExpanded) ...[
        const SizedBox(height: AppSpacing.xs),
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              CheckInResultCopy.optionExamples[option.id] ?? option.label,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 12, height: 1.4),
            ),
          ),
      ],
    ];
  }

  List<Widget> _oneTapAnswerSection(List<TomorrowCheckInOption> options) {
    return [
      Text(
        _t('todayHappened', ConsumerUiCopy.tomorrowCheckInTodayHappenedLabel),
        style: VoiceMemoryTypography.bodyStyle(
          color: AppColors.textSecondary,
        ).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: AppSpacing.sm),
      for (final option in options) ...[
        _OneTapAnswerButton(
          label: _optionLabel(option),
          selected: _selectedOptionId == option.id,
          onTap: _saving ? null : () => _onOptionTap(option),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    ];
  }

  List<Widget> _guidedAnswerSection(List<TomorrowCheckInOption> options) {
    if (!_guidedStarted) {
      return [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _onGuidedStart,
            child: const Text(ConsumerUiCopy.guidedCheckInAnswerCta),
          ),
        ),
      ];
    }

    final showedUp = _optionById('showed_up_again');
    final didNotShow = _optionById('not_today');
    final lighter = _optionById('lighter');
    final heavier = _optionById('heavier');

    return [
      Text(
        ConsumerUiCopy.guidedCheckInPickClosest,
        style: VoiceMemoryTypography.bodyStyle(
          color: AppColors.textSecondary,
        ).copyWith(fontSize: 13, height: 1.4),
      ),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (showedUp != null)
            _OptionChip(
              label: ConsumerUiCopy.guidedCheckInShowedUp,
              selected: _selectedOptionId == showedUp.id,
              onTap: _saving ? null : () => _onOptionTap(showedUp),
            ),
          if (didNotShow != null)
            _OptionChip(
              label: ConsumerUiCopy.guidedCheckInDidNotShowUp,
              selected: _selectedOptionId == didNotShow.id,
              onTap: _saving ? null : () => _onOptionTap(didNotShow),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      if (!_guidedSecondaryRevealed)
        TextButton(
          onPressed: () =>
              setState(() => _guidedSecondaryRevealed = true),
          child: const Text(ConsumerUiCopy.guidedCheckInOtherAnswers),
        )
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (lighter != null)
              _OptionChip(
                label: lighter.label,
                selected: _selectedOptionId == lighter.id,
                onTap: _saving ? null : () => _onOptionTap(lighter),
              ),
            if (heavier != null)
              _OptionChip(
                label: heavier.label,
                selected: _selectedOptionId == heavier.id,
                onTap: _saving ? null : () => _onOptionTap(heavier),
              ),
          ],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final options = widget.checkIn.options;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _accentBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
            ConsumerUiCopy.tomorrowCheckInDueTitle,
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.accentPrimary,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ConsumerUiCopy.tomorrowCheckInDueSubtitle,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 14, height: 1.4),
          ),
          if (widget.plannedAnchor != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: AppColors.accentPrimary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Planned for: ${widget.plannedAnchor!.displayLabel}',
                  style: VoiceMemoryTypography.bodyStyle(
                    color: AppColors.accentPrimary,
                  ).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            _t('yesterdayChose',
                ConsumerUiCopy.tomorrowCheckInYesterdayChosenLabel),
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.checkIn.question,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...(widget.guided
              ? _guidedAnswerSection(options)
              : widget.oneTapMode
                  ? _oneTapAnswerSection(options)
                  : _standardAnswerSection(options)),
          if (selected != null && widget.oneTapMode) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              ConsumerUiCopy.tomorrowCheckInOneTapRecordPrompt,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textPrimary,
              ).copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ConsumerUiCopy.tomorrowCheckInOneTapRecordHelper,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _onRecord,
                child: Text(_t('recordOneMoment',
                    ConsumerUiCopy.tomorrowCheckInOneTapRecordCta)),
              ),
            ),
          ] else if (selected != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              ConsumerUiCopy.tomorrowCheckInMomentCompareLine,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textPrimary,
              ).copyWith(fontSize: 14, height: 1.45),
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
              child: Text(
                _followUp(selected),
                style: VoiceMemoryTypography.bodyStyle(
                  color: AppColors.textSecondary,
                ).copyWith(fontSize: 14, height: 1.45, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              ConsumerUiCopy.tomorrowCheckInShortHelper,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _onRecord,
                child: Text(_t('recordOneMoment',
                    ConsumerUiCopy.tomorrowCheckInRecordCta)),
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }
}

/// Large full-width answer button for the return-day one-tap flow.
class _OneTapAnswerButton extends StatelessWidget {
  const _OneTapAnswerButton({
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: selected
            ? AppColors.accentPrimary.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? AppColors.accentPrimary
                    : const Color(0xFFF5E6D3),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              style: VoiceMemoryTypography.bodyStyle(
                color:
                    selected ? AppColors.accentPrimary : AppColors.textPrimary,
              ).copyWith(
                fontSize: 16,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap!(),
      showCheckmark: false,
      selectedColor: AppColors.accentPrimary.withValues(alpha: 0.15),
      side: BorderSide(
        color: selected ? AppColors.accentPrimary : const Color(0xFFF5E6D3),
      ),
      labelStyle: VoiceMemoryTypography.bodyStyle(
        color: selected ? AppColors.accentPrimary : AppColors.textSecondary,
      ).copyWith(fontSize: 13, fontWeight: selected ? FontWeight.w600 : null),
    );
  }
}
