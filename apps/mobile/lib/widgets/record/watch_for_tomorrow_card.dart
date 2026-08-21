import 'dart:async';

import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import 'package:archiveme_mobile/features/tomorrow_return/watch_for_coordinator.dart';
import 'package:archiveme_mobile/features/tomorrow_return/watch_for_model.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/trial/check_in_worth_rating_prompt.dart';
import 'package:flutter/material.dart';

/// Post-save card suggesting one specific watch-for for tomorrow.
class WatchForTomorrowCard extends StatefulWidget {
  const WatchForTomorrowCard({
    required this.suggestion, super.key,
    this.onChooseAnother,
    this.onAccept,
  });

  final WatchForItem suggestion;

  /// Called when user taps "Choose another".
  final VoidCallback? onChooseAnother;

  /// Test hook; defaults to [WatchForCoordinator.acceptSuggestedWatchFor].
  final Future<void> Function(WatchForItem item)? onAccept;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = AppColors.warmBorder;

  @override
  State<WatchForTomorrowCard> createState() => _WatchForTomorrowCardState();
}

class _WatchForTomorrowCardState extends State<WatchForTomorrowCard> {
  bool _accepted = false;
  bool _saving = false;
  String? _checkInIdForRating;
  bool _questionRated = false;

  @override
  void initState() {
    super.initState();
    if (widget.suggestion.hasRichPrompt) {
      final strength = widget.suggestion.promptStrength ?? 'medium';
      unawaited(ActivationTracker.trackWatchForPromptShown(strength: strength));
    }
  }

  @override
  Widget build(BuildContext context) {
    final chips = widget.suggestion.chips.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: WatchForTomorrowCard._warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WatchForTomorrowCard._warmBorder),
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
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                ConsumerUiCopy.watchForTomorrowAcceptedLine,
                style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                  fontSize: 17,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
        if (_checkInIdForRating != null && !_questionRated)
          CheckInWorthRatingPrompt(
            checkInId: _checkInIdForRating!,
            onRated: () => setState(() => _questionRated = true),
          ),
      ],
    );
  }

  Widget _promptContent(List<String> chips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.suggestion.hasRichPrompt
              ? widget.suggestion.displayShortPrompt
              : ConsumerUiCopy.watchForTomorrowTitle,
          style: VoiceMemoryTypography.cardTitleStyle().copyWith(
            fontSize: 18,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          widget.suggestion.hasRichPrompt
              ? widget.suggestion.displaySpecificPrompt
              : widget.suggestion.text,
          style: VoiceMemoryTypography.bodyStyle().copyWith(height: 1.45),
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map(
                  (c) => Chip(
                    label: Text(c),
                    backgroundColor: AppColors.backgroundSecondary,
                    side: const BorderSide(color: WatchForTomorrowCard._warmBorder),
                    labelStyle: VoiceMemoryTypography.bodyStyle(
                      color: AppColors.textSecondary,
                    ).copyWith(fontSize: 13),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
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
                : const Text(ConsumerUiCopy.watchForTomorrowUseCta),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            onPressed: _saving ? null : widget.onChooseAnother,
            child: const Text(ConsumerUiCopy.watchForTomorrowChooseAnotherCta),
          ),
        ),
      ],
    );
  }

  Future<void> _onAccept() async {
    setState(() => _saving = true);
    try {
      final accept =
          widget.onAccept ?? WatchForCoordinator.acceptSuggestedWatchFor;
      await accept(widget.suggestion);
      await TomorrowCheckInCoordinator.createFromWatchFor(widget.suggestion);
      if (widget.suggestion.promptStrength != null) {
        await ActivationTracker.trackWatchForPromptAccepted(
          strength: widget.suggestion.promptStrength!,
        );
      }
      if (!mounted) return;
      final active = await TomorrowCheckInCoordinator.loadActive();
      setState(() {
        _accepted = true;
        _saving = false;
        _checkInIdForRating = active?.id;
      });
    } catch (_, stackTrace) {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }
}