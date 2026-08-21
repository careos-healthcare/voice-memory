import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/low_friction_return/low_friction_return_analytics.dart';
import 'package:archiveme_mobile/features/low_friction_return/low_friction_return_copy.dart';
import 'package:archiveme_mobile/features/low_friction_return/low_friction_return_engine.dart';
import 'package:archiveme_mobile/features/low_friction_return/low_friction_return_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Permission-first return card — skip, one sentence, or tiny prompt only.
class LowFrictionReturnCard extends StatefulWidget {
  const LowFrictionReturnCard({
    required this.source, required this.entryCount, required this.onSaveOneSentence, required this.onPromptSelected, super.key,
    this.store,
  });

  const LowFrictionReturnCard.test({
    required this.source, required this.entryCount, required this.onSaveOneSentence, required this.onPromptSelected, super.key,
    this.store,
  });

  final String source;
  final int entryCount;
  final VoidCallback onSaveOneSentence;
  final ValueChanged<String> onPromptSelected;
  final LowFrictionReturnStore? store;

  @override
  State<LowFrictionReturnCard> createState() => _LowFrictionReturnCardState();
}

class _LowFrictionReturnCardState extends State<LowFrictionReturnCard> {
  var _trackedSeen = false;
  var _promptsExpanded = false;
  LowFrictionReturnPromptType? _selectedPromptType;
  var _skippedToday = false;

  LowFrictionReturnStore? get _store =>
      widget.store ?? LowFrictionReturnStore.instance();

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    LowFrictionReturnAnalytics.seen(
      source: widget.source,
      entryCount: widget.entryCount,
    );
  }

  Future<void> _handleSkipToday() async {
    LowFrictionReturnAnalytics.actionTapped(
      source: widget.source,
      entryCount: widget.entryCount,
      actionType: LowFrictionReturnActionType.skipToday,
    );
    await _store?.dismissForDay();
    if (!mounted) return;
    setState(() => _skippedToday = true);
  }

  void _handleSaveOneSentence() {
    LowFrictionReturnAnalytics.actionTapped(
      source: widget.source,
      entryCount: widget.entryCount,
      actionType: LowFrictionReturnActionType.saveOneSentence,
    );
    widget.onSaveOneSentence();
  }

  void _handleUseTinyPrompt() {
    LowFrictionReturnAnalytics.actionTapped(
      source: widget.source,
      entryCount: widget.entryCount,
      actionType: LowFrictionReturnActionType.useTinyPrompt,
    );
    setState(() => _promptsExpanded = true);
  }

  void _handlePromptSelected(LowFrictionReturnPromptType type) {
    final prompt = LowFrictionReturnCopy.promptTextFor(type);
    LowFrictionReturnAnalytics.promptSelected(
      source: widget.source,
      entryCount: widget.entryCount,
      promptType: type,
    );
    setState(() => _selectedPromptType = type);
    widget.onPromptSelected(prompt);
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: const Key('low_friction_return_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            LowFrictionReturnCopy.title,
            key: const Key('low_friction_return_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            LowFrictionReturnCopy.body,
            key: const Key('low_friction_return_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            LowFrictionReturnCopy.permissionLine,
            key: const Key('low_friction_return_permission'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            LowFrictionReturnCopy.recordAnythingReminder,
            key: const Key('low_friction_return_record_anything'),
            style: bodyStyle,
          ),
          if (_skippedToday) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              LowFrictionReturnCopy.afterSkip,
              key: const Key('low_friction_return_after_skip'),
              style: bodyStyle.copyWith(color: AppColors.textPrimary),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 44,
              width: double.infinity,
              child: FilledButton(
                key: const Key('low_friction_return_save_one_sentence'),
                onPressed: _handleSaveOneSentence,
                child: const Text(LowFrictionReturnCopy.saveOneSentenceAction),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton(
                  key: const Key('low_friction_return_use_tiny_prompt'),
                  onPressed: _handleUseTinyPrompt,
                  child: const Text(LowFrictionReturnCopy.useTinyPromptAction),
                ),
                TextButton(
                  key: const Key('low_friction_return_skip_today'),
                  onPressed: () => unawaited(_handleSkipToday()),
                  child: const Text(LowFrictionReturnCopy.skipTodayAction),
                ),
              ],
            ),
            if (_promptsExpanded) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final prompt in LowFrictionReturnPromptType.all)
                    FilterChip(
                      key: Key('low_friction_return_prompt_${prompt.name}'),
                      label: Text(LowFrictionReturnCopy.promptTextFor(prompt)),
                      selected: _selectedPromptType == prompt,
                      onSelected: (_) => _handlePromptSelected(prompt),
                      showCheckmark: false,
                    ),
                ],
              ),
            ],
            if (_selectedPromptType != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                LowFrictionReturnCopy.afterPromptSelected,
                key: const Key('low_friction_return_after_prompt'),
                style: bodyStyle.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ],
        ],
      ),
    );
  }
}