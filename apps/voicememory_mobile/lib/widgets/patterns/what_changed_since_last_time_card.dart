import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/what_changed_since_last_time_analytics.dart';
import '../../features/early_archive/what_changed_since_last_time_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Patterns / Archive longitudinal return comparison — no CTAs.
class WhatChangedSinceLastTimeCard extends StatelessWidget {
  const WhatChangedSinceLastTimeCard({
    super.key,
    required this.result,
    required this.entryCount,
  });

  final WhatChangedSinceLastTime result;
  final int entryCount;

  void _trackSeen() {
    WhatChangedSinceLastTimeAnalytics.seen(
      entryCount: entryCount,
      comparisonState: result.state,
      hasPhrase: result.hasPhrase,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeen();
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );
    final rowLabelStyle = ArchiveMobileTypography.cardLabel(context).copyWith(
      color: AppColors.textSecondary,
    );
    final rowPhraseStyle = bodyStyle.copyWith(
      color: AppColors.textPrimary,
    );

    return Container(
      key: const Key('what_changed_since_last_time_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF7FAFC)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            result.title,
            key: const Key('what_changed_since_last_time_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.summary,
            key: Key('what_changed_since_last_time_summary_${result.state.name}'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.evidenceLabel,
            key: const Key('what_changed_since_last_time_evidence_label'),
            style: rowLabelStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final row in result.evidenceRows)
            Padding(
              key: Key('what_changed_since_last_time_row_${row.label}'),
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.label, style: rowLabelStyle),
                  if (row.phrase != null && row.phrase!.isNotEmpty)
                    Text(
                      row.phrase!,
                      key: Key(
                        'what_changed_since_last_time_phrase_${row.label}',
                      ),
                      style: rowPhraseStyle,
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.footer,
            key: const Key('what_changed_since_last_time_footer'),
            style: bodyStyle.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
