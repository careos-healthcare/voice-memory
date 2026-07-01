import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/beta/confirmed_repeat_beta_feedback_analytics.dart';
import '../../features/beta/confirmed_repeat_beta_feedback_copy.dart';
import '../../features/beta/confirmed_repeat_beta_feedback_gates.dart';
import '../../features/beta/confirmed_repeat_beta_feedback_models.dart';
import '../../features/beta/confirmed_repeat_beta_feedback_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// One-time beta feedback after confirmed repeat — dismissible, never blocks
/// recording, structured follow-up stored locally only.
class ConfirmedRepeatBetaFeedbackCard extends StatefulWidget {
  const ConfirmedRepeatBetaFeedbackCard({
    super.key,
    required this.entryCount,
    required this.surface,
    required this.viewingConfirmedRepeat,
    required this.isRecording,
    this.store,
    this.skipPrefsLoad = false,
    this.initialState,
    this.onChanged,
  });

  const ConfirmedRepeatBetaFeedbackCard.test({
    super.key,
    required this.entryCount,
    required this.surface,
    required this.viewingConfirmedRepeat,
    required this.isRecording,
    this.store,
    this.onChanged,
    ConfirmedRepeatBetaFeedbackState? initialState,
  })  : skipPrefsLoad = true,
        initialState = initialState;

  final int entryCount;
  final String surface;
  final bool viewingConfirmedRepeat;
  final bool isRecording;
  final ConfirmedRepeatBetaFeedbackStore? store;
  final bool skipPrefsLoad;
  final ConfirmedRepeatBetaFeedbackState? initialState;
  final VoidCallback? onChanged;

  @override
  State<ConfirmedRepeatBetaFeedbackCard> createState() =>
      _ConfirmedRepeatBetaFeedbackCardState();
}

class _ConfirmedRepeatBetaFeedbackCardState
    extends State<ConfirmedRepeatBetaFeedbackCard> {
  ConfirmedRepeatBetaFeedbackStore? _store;
  ConfirmedRepeatBetaFeedbackState _state =
      ConfirmedRepeatBetaFeedbackState.empty;
  ConfirmedRepeatBetaFeedbackChoice? _pendingChoice;
  bool _loading = true;
  bool _showFollowUpStep = false;

  @override
  void initState() {
    super.initState();
    if (widget.skipPrefsLoad) {
      _state = widget.initialState ?? ConfirmedRepeatBetaFeedbackState.empty;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    _store ??= widget.store ?? ConfirmedRepeatBetaFeedbackStore.instance();
    await ConfirmedRepeatBetaFeedbackStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _state = ConfirmedRepeatBetaFeedbackStore.cached;
      _loading = false;
    });
  }

  Future<void> _dismiss() async {
    _store ??= widget.store ?? ConfirmedRepeatBetaFeedbackStore.instance();
    ConfirmedRepeatBetaFeedbackAnalytics.recordDismissed(
      surface: widget.surface,
      entryCount: widget.entryCount,
    );
    await _store!.dismiss();
    if (!mounted) return;
    setState(() => _state = ConfirmedRepeatBetaFeedbackStore.cached);
    widget.onChanged?.call();
  }

  Future<void> _saveResponse({
    required ConfirmedRepeatBetaFeedbackChoice choice,
    ConfirmedRepeatBetaFeedbackReason? reason,
  }) async {
    _store ??= widget.store ?? ConfirmedRepeatBetaFeedbackStore.instance();
    await _store!.saveResponse(choice: choice, reason: reason);
    ConfirmedRepeatBetaFeedbackAnalytics.recordAnswer(
      surface: widget.surface,
      entryCount: widget.entryCount,
      answer: choice,
      reason: reason,
    );
    if (!mounted) return;
    setState(() {
      _state = ConfirmedRepeatBetaFeedbackStore.cached;
      _showFollowUpStep = false;
      _pendingChoice = null;
    });
    widget.onChanged?.call();
  }

  void _selectChoice(ConfirmedRepeatBetaFeedbackChoice choice) {
    if (!choice.showsFollowUp) {
      unawaited(_saveResponse(choice: choice));
      return;
    }
    setState(() {
      _pendingChoice = choice;
      _showFollowUpStep = true;
    });
  }

  Future<void> _selectReason(ConfirmedRepeatBetaFeedbackReason reason) async {
    final choice = _pendingChoice;
    if (choice == null) return;
    await _saveResponse(choice: choice, reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink(
        key: Key('confirmed_repeat_beta_feedback_loading'),
      );
    }

    if (_state.completed) {
      if (_state.choice != null) {
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            ConfirmedRepeatBetaFeedbackCopy.thanks,
            key: const Key('confirmed_repeat_beta_feedback_thanks'),
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        );
      }
      return const SizedBox.shrink(
        key: Key('confirmed_repeat_beta_feedback_hidden'),
      );
    }

    if (!ConfirmedRepeatBetaFeedbackGates.shouldShow(
      viewingConfirmedRepeat: widget.viewingConfirmedRepeat,
      isRecording: widget.isRecording,
      entryCount: widget.entryCount,
      state: _state,
    )) {
      return const SizedBox.shrink(
        key: Key('confirmed_repeat_beta_feedback_hidden'),
      );
    }

    return Container(
      key: const Key('confirmed_repeat_beta_feedback_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _showFollowUpStep
                      ? ConfirmedRepeatBetaFeedbackCopy.followUpPrompt
                      : ConfirmedRepeatBetaFeedbackCopy.prompt,
                  key: const Key('confirmed_repeat_beta_feedback_title'),
                  style: ArchiveMobileTypography.listTitle(context),
                ),
              ),
              IconButton(
                key: const Key('confirmed_repeat_beta_feedback_dismiss'),
                onPressed: _dismiss,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: ConfirmedRepeatBetaFeedbackCopy.dismiss,
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          if (!_showFollowUpStep) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton(
                  key: const Key('confirmed_repeat_beta_feedback_yes'),
                  onPressed: () =>
                      _selectChoice(ConfirmedRepeatBetaFeedbackChoice.yes),
                  child: const Text(ConfirmedRepeatBetaFeedbackCopy.yes),
                ),
                OutlinedButton(
                  key: const Key('confirmed_repeat_beta_feedback_somewhat'),
                  onPressed: () => _selectChoice(
                    ConfirmedRepeatBetaFeedbackChoice.somewhat,
                  ),
                  child: const Text(ConfirmedRepeatBetaFeedbackCopy.somewhat),
                ),
                OutlinedButton(
                  key: const Key('confirmed_repeat_beta_feedback_not_really'),
                  onPressed: () => _selectChoice(
                    ConfirmedRepeatBetaFeedbackChoice.notReally,
                  ),
                  child: const Text(ConfirmedRepeatBetaFeedbackCopy.notReally),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final reason in ConfirmedRepeatBetaFeedbackReason.values)
                  OutlinedButton(
                    key: Key(
                      'confirmed_repeat_beta_feedback_reason_${reason.name}',
                    ),
                    onPressed: () => _selectReason(reason),
                    child: Text(reason.label),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
