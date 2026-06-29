import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/early_first_signal_engine.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Early archive card for 1–2 saved moments — receipt or cautious first signal.
class EarlyFirstSignalCard extends StatelessWidget {
  const EarlyFirstSignalCard({
    super.key,
    required this.signal,
    required this.onPrimary,
  });

  final EarlyFirstSignalModel signal;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('early_first_signal_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFFFFBF5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            signal.title,
            key: const Key('early_first_signal_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          for (final line in signal.lines) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              line,
              key: ValueKey('early_first_signal_line_$line'),
              style: ArchiveMobileTypography.explanationBody(context).copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('early_first_signal_primary_cta'),
            onPressed: onPrimary,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentPrimary,
              foregroundColor: Colors.white,
            ),
            child: Text(signal.primaryCta),
          ),
        ],
      ),
    );
  }
}
