import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/return_after_proof/return_after_proof_analytics.dart';
import '../../features/return_after_proof/return_after_proof_copy.dart';
import '../../features/return_after_proof/return_after_proof_model.dart';
import '../../features/return_after_proof/return_after_proof_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// One clear reason to return after proof — prompt line only, no fake entries.
class ReturnAfterProofCard extends StatefulWidget {
  const ReturnAfterProofCard({
    super.key,
    required this.result,
    required this.onPromptSelected,
    this.store,
  });

  const ReturnAfterProofCard.test({
    super.key,
    required this.result,
    required this.onPromptSelected,
    this.store,
  });

  final ReturnAfterProofResult result;
  final ValueChanged<String> onPromptSelected;
  final ReturnAfterProofStore? store;

  @override
  State<ReturnAfterProofCard> createState() => _ReturnAfterProofCardState();
}

class _ReturnAfterProofCardState extends State<ReturnAfterProofCard> {
  var _trackedSeen = false;
  ReturnAfterProofPromptType? _selectedPromptType;
  var _dismissedToday = false;

  ReturnAfterProofStore? get _store =>
      widget.store ?? ReturnAfterProofStore.instance();

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    ReturnAfterProofAnalytics.seen(result: widget.result);
  }

  Future<void> _handlePromptTap(ReturnAfterProofPrompt prompt) async {
    if (prompt.type == ReturnAfterProofPromptType.notToday) {
      ReturnAfterProofAnalytics.dismissedToday(result: widget.result);
      await _store?.dismissForDay();
      if (!mounted) return;
      setState(() {
        _selectedPromptType = prompt.type;
        _dismissedToday = true;
      });
      return;
    }

    ReturnAfterProofAnalytics.promptTapped(
      result: widget.result,
      promptType: prompt.type,
    );
    setState(() => _selectedPromptType = prompt.type);
    widget.onPromptSelected(prompt.selectedLine);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.result.shouldShow) return const SizedBox.shrink();
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );

    return Container(
      key: const Key('return_after_proof_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF8FAFC)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('return_after_proof_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('return_after_proof_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_dismissedToday) ...[
            Text(
              ReturnAfterProofCopy.afterNotTodayDismiss,
              key: const Key('return_after_proof_after_not_today'),
              style: bodyStyle.copyWith(color: AppColors.textPrimary),
            ),
          ] else ...[
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final prompt in widget.result.prompts)
                  FilterChip(
                    key: Key('return_after_proof_prompt_${prompt.type.name}'),
                    label: Text(prompt.label),
                    selected: _selectedPromptType == prompt.type,
                    onSelected: (_) => unawaited(_handlePromptTap(prompt)),
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.result.closingLine,
              key: const Key('return_after_proof_closing'),
              style: bodyStyle,
            ),
            if (_selectedPromptType != null &&
                _selectedPromptType != ReturnAfterProofPromptType.notToday) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                ReturnAfterProofCopy.selectedPromptLineFor(
                  _selectedPromptType!,
                ),
                key: const Key('return_after_proof_selected_line'),
                style: bodyStyle.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
