import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_analytics.dart';
import '../../features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_copy.dart';
import '../../features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_model.dart';
import '../../features/second_moment_return/second_moment_return_analytics.dart';
import '../../features/second_moment_return/second_moment_return_model.dart';
import '../../features/second_moment_return/second_moment_return_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// One-entry return card — notice prompts only, no daily pressure.
class SecondMomentReturnCard extends StatefulWidget {
  const SecondMomentReturnCard({
    super.key,
    required this.result,
    required this.onNoticedSomething,
    required this.onPromptSelected,
    required this.onSaveOneSentence,
    this.store,
  });

  const SecondMomentReturnCard.test({
    super.key,
    required this.result,
    required this.onNoticedSomething,
    required this.onPromptSelected,
    required this.onSaveOneSentence,
    this.store,
  });

  final SecondMomentReturnResult result;
  final VoidCallback onNoticedSomething;
  final ValueChanged<String> onPromptSelected;
  final VoidCallback onSaveOneSentence;
  final SecondMomentReturnStore? store;

  @override
  State<SecondMomentReturnCard> createState() => _SecondMomentReturnCardState();
}

class _SecondMomentReturnCardState extends State<SecondMomentReturnCard> {
  var _trackedSeen = false;
  var _promptsExpanded = false;
  var _noticedSomething = false;
  var _dismissedToday = false;

  SecondMomentReturnStore? get _store =>
      widget.store ?? SecondMomentReturnStore.instance();

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    SecondMomentReturnAnalytics.seen(result: widget.result);
    if (widget.result.returnReasonLine.isNotEmpty) {
      RevenueLiftExperimentV2Analytics.seen(
        context: RevenueLiftExperimentV2SeenContext(
          source: widget.result.source,
          surface: 'second_moment_return_card',
          entryCount: widget.result.entryCount,
          area: RevenueLiftExperimentV2Area.returnReason,
        ),
      );
    }
  }

  void _handleNoticedSomething() {
    SecondMomentReturnAnalytics.actionTapped(
      result: widget.result,
      actionType: SecondMomentReturnActionType.noticedSomething,
    );
    setState(() => _noticedSomething = true);
    widget.onNoticedSomething();
  }

  void _handleShowWhatToNotice() {
    SecondMomentReturnAnalytics.actionTapped(
      result: widget.result,
      actionType: SecondMomentReturnActionType.showWhatToNotice,
    );
    setState(() => _promptsExpanded = true);
  }

  Future<void> _handleNotToday() async {
    SecondMomentReturnAnalytics.actionTapped(
      result: widget.result,
      actionType: SecondMomentReturnActionType.notToday,
    );
    SecondMomentReturnAnalytics.dismissedToday(result: widget.result);
    await _store?.dismissForDay();
    if (!mounted) return;
    setState(() => _dismissedToday = true);
  }

  void _handlePromptSelected(SecondMomentReturnPrompt prompt) {
    SecondMomentReturnAnalytics.promptTapped(
      result: widget.result,
      promptType: prompt.type,
    );
    widget.onPromptSelected(prompt.text);
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: const Key('second_moment_return_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('second_moment_return_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('second_moment_return_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          if (widget.result.returnReasonLine.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.result.returnReasonLine,
              key: const Key('second_moment_return_reason_line'),
              style: bodyStyle.copyWith(color: AppColors.textPrimary),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.noticeLine,
            key: const Key('second_moment_return_notice'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.noPressureLine,
            key: const Key('second_moment_return_no_pressure'),
            style: bodyStyle,
          ),
          if (_dismissedToday) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.result.afterNotToday,
              key: const Key('second_moment_return_after_not_today'),
              style: bodyStyle.copyWith(color: AppColors.textPrimary),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 44,
              width: double.infinity,
              child: FilledButton(
                key: const Key('second_moment_return_noticed_something'),
                onPressed: _handleNoticedSomething,
                child: Text(widget.result.noticedSomethingAction),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton(
                  key: const Key('second_moment_return_show_what_to_notice'),
                  onPressed: _handleShowWhatToNotice,
                  child: Text(widget.result.showWhatToNoticeAction),
                ),
                TextButton(
                  key: const Key('second_moment_return_not_today'),
                  onPressed: () => unawaited(_handleNotToday()),
                  child: Text(widget.result.notTodayAction),
                ),
              ],
            ),
            if (_noticedSomething) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.result.afterNoticedSomething,
                key: const Key('second_moment_return_after_noticed'),
                style: bodyStyle.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: 44,
                width: double.infinity,
                child: FilledButton(
                  key: const Key('second_moment_return_save_one_sentence'),
                  onPressed: widget.onSaveOneSentence,
                  child: const Text('Save one sentence'),
                ),
              ),
            ],
            if (_promptsExpanded) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final prompt in widget.result.prompts)
                    FilterChip(
                      key: Key(
                        'second_moment_return_prompt_${prompt.type.name}',
                      ),
                      label: Text(prompt.text),
                      onSelected: (_) => _handlePromptSelected(prompt),
                      showCheckmark: false,
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
