import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/tomorrow_return/tomorrow_commitment_model.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../../theme/voicememory_typography.dart';

/// Patterns-tab status for an active or completed tomorrow commitment.
class TomorrowReturnStatusCard extends StatelessWidget {
  const TomorrowReturnStatusCard({
    super.key,
    required this.commitment,
    required this.state,
  });

  final TomorrowCommitment commitment;
  final TomorrowCommitmentDisplayState state;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case TomorrowCommitmentDisplayState.awaitingReturn:
        return _AwaitingCard(commitment: commitment);
      case TomorrowCommitmentDisplayState.completedToday:
        return _CompletedCard();
      case TomorrowCommitmentDisplayState.hidden:
        return const SizedBox.shrink();
    }
  }
}

class _AwaitingCard extends StatelessWidget {
  const _AwaitingCard({required this.commitment});

  final TomorrowCommitment commitment;

  @override
  Widget build(BuildContext context) {
    final chips = commitment.displayWatchChips;
    final chipText =
        chips.isEmpty ? 'what you saved yesterday' : chips.join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.flat(
        background: const Color(0xFFFFFBF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsumerUiCopy.tomorrowReturnStatusCameBackTitle,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 17,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${ConsumerUiCopy.tomorrowReturnStatusCameBackBodyPrefix} $chipText. '
            '${ConsumerUiCopy.tomorrowReturnStatusCameBackBodySuffix}',
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(height: 1.45),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: () => context.go('/record'),
              child: const Text(ConsumerUiCopy.patternsComeBackRecordCta),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.flat(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsumerUiCopy.tomorrowReturnStatusKeptGoingTitle,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 17,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ConsumerUiCopy.tomorrowReturnStatusKeptGoingBody,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(height: 1.45),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () => context.go('/belief-changes'),
              child: const Text(ConsumerUiCopy.tomorrowReturnStatusSeeChangedCta),
            ),
          ),
        ],
      ),
    );
  }
}
