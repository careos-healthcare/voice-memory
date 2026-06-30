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

/// One-time beta feedback after the first confirmed repeat — dismissible,
/// never blocks recording, optional note stored locally only.
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
  final _noteController = TextEditingController();
  bool _loading = true;
  bool _showNoteStep = false;

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

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    _store ??= widget.store ?? ConfirmedRepeatBetaFeedbackStore.instance();
    ConfirmedRepeatBetaFeedbackAnalytics.recordDismissed(
      entryCount: widget.entryCount,
      surface: widget.surface,
    );
    await _store!.dismiss();
    if (!mounted) return;
    setState(() => _state = ConfirmedRepeatBetaFeedbackStore.cached);
    widget.onChanged?.call();
  }

  void _selectChoice(ConfirmedRepeatBetaFeedbackChoice choice) {
    ConfirmedRepeatBetaFeedbackAnalytics.recordChoice(
      choice: choice,
      entryCount: widget.entryCount,
      surface: widget.surface,
    );
    setState(() {
      _pendingChoice = choice;
      _showNoteStep = true;
    });
  }

  Future<void> _saveNote({required bool includeNote}) async {
    final choice = _pendingChoice;
    if (choice == null) return;
    _store ??= widget.store ?? ConfirmedRepeatBetaFeedbackStore.instance();
    final note = includeNote ? _noteController.text : null;
    await _store!.saveResponse(choice: choice, note: note);
    ConfirmedRepeatBetaFeedbackAnalytics.recordNoteSaved(
      choice: choice,
      entryCount: widget.entryCount,
      surface: widget.surface,
      hasNote: note?.trim().isNotEmpty == true,
    );
    if (!mounted) return;
    setState(() {
      _state = ConfirmedRepeatBetaFeedbackStore.cached;
      _showNoteStep = false;
      _pendingChoice = null;
    });
    widget.onChanged?.call();
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
      state: _state,
    )) {
      return const SizedBox.shrink(
        key: Key('confirmed_repeat_beta_feedback_hidden'),
      );
    }

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
    );

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
                  _showNoteStep
                      ? ConfirmedRepeatBetaFeedbackCopy.notePrompt
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
          if (!_showNoteStep) ...[
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
                  key: const Key('confirmed_repeat_beta_feedback_not_really'),
                  onPressed: () => _selectChoice(
                    ConfirmedRepeatBetaFeedbackChoice.notReally,
                  ),
                  child: const Text(ConfirmedRepeatBetaFeedbackCopy.notReally),
                ),
                OutlinedButton(
                  key: const Key('confirmed_repeat_beta_feedback_need_more'),
                  onPressed: () => _selectChoice(
                    ConfirmedRepeatBetaFeedbackChoice.needMore,
                  ),
                  child: const Text(ConfirmedRepeatBetaFeedbackCopy.needMore),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('confirmed_repeat_beta_feedback_note_field'),
              controller: _noteController,
              maxLines: 3,
              maxLength: ConfirmedRepeatBetaFeedbackStore.maxNoteLength,
              decoration: InputDecoration(
                hintText: ConfirmedRepeatBetaFeedbackCopy.noteHint,
                hintStyle: bodyStyle,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('confirmed_repeat_beta_feedback_skip_note'),
                    onPressed: () => _saveNote(includeNote: false),
                    child: const Text(ConfirmedRepeatBetaFeedbackCopy.skipNote),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: FilledButton(
                    key: const Key('confirmed_repeat_beta_feedback_save_note'),
                    onPressed: () => _saveNote(includeNote: true),
                    child: const Text(ConfirmedRepeatBetaFeedbackCopy.saveNote),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
