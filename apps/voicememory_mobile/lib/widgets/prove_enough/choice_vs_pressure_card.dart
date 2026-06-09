import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/prove_enough/prove_enough_post_record_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Choice vs pressure breakdown for a prove_enough moment.
class ChoiceVsPressureCard extends StatelessWidget {
  const ChoiceVsPressureCard({
    super.key,
    required this.model,
  });

  final ProveEnoughPostRecordModel model;

  static const _emptyCopy = 'Nothing clear in this moment yet.';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choice vs pressure',
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Section(
            title: 'What looked like choice',
            items: model.transcriptWeak
                ? const [_emptyCopy]
                : _itemsOrFallback(model.whatLookedLikeChoice),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Section(
            title: 'What looked like pressure',
            items: model.transcriptWeak
                ? const [_emptyCopy]
                : _itemsOrFallback(model.whatLookedLikePressure),
          ),
        ],
      ),
    );
  }

  static List<String> _itemsOrFallback(List<String> items) {
    if (items.isEmpty) return const [_emptyCopy];
    return items;
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '· ',
                  style: ArchiveMobileTypography.body(context).copyWith(
                    color: AppColors.accentPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: ArchiveMobileTypography.body(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
