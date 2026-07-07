import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/what_to_notice_next/what_to_notice_next_analytics.dart';
import '../../features/what_to_notice_next/what_to_notice_next_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Read-only observation guidance — optional prompt line only, no routing.
class WhatToNoticeNextCard extends StatefulWidget {
  const WhatToNoticeNextCard({
    super.key,
    required this.result,
    this.onPromptSelected,
  });

  const WhatToNoticeNextCard.test({
    super.key,
    required this.result,
    this.onPromptSelected,
  });

  final WhatToNoticeNextResult result;
  final ValueChanged<String>? onPromptSelected;

  @override
  State<WhatToNoticeNextCard> createState() => _WhatToNoticeNextCardState();
}

class _WhatToNoticeNextCardState extends State<WhatToNoticeNextCard> {
  var _trackedSeen = false;
  WhatToNoticeNextPromptType? _selectedPromptType;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    WhatToNoticeNextAnalytics.seen(result: widget.result);
  }

  void _handlePromptTap(WhatToNoticeNextPrompt prompt) {
    WhatToNoticeNextAnalytics.promptTapped(
      result: widget.result,
      promptType: prompt.type,
    );
    setState(() => _selectedPromptType = prompt.type);
    widget.onPromptSelected?.call(prompt.text);
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );

    return Container(
      key: const Key('what_to_notice_next_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF8FAFC)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('what_to_notice_next_title'),
            style: ArchiveMobileTypography.cardLabel(context).copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('what_to_notice_next_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final prompt in widget.result.prompts)
                FilterChip(
                  key: Key('what_to_notice_next_prompt_${prompt.type.name}'),
                  label: Text(prompt.text),
                  selected: _selectedPromptType == prompt.type,
                  onSelected: widget.onPromptSelected == null
                      ? null
                      : (_) => _handlePromptTap(prompt),
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.closingLine,
            key: const Key('what_to_notice_next_closing'),
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}
