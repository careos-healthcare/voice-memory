import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/collections/archive_collection.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// One collection on the Collections screen: name and entry count.
class CollectionCard extends StatelessWidget {
  const CollectionCard({super.key, required this.collection, this.onTap});

  final ArchiveCollection collection;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final count = collection.entryIds.length;
    return InkWell(
      key: Key('collection_card_${collection.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(VoiceMemoryCards.radius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: VoiceMemoryCards.flat(background: AppColors.surfaceAlt),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ArchiveMobileTypography.cardLabel(context),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 1 ? '1 entry' : '$count entries',
                    style: ArchiveMobileTypography.responsiveHelper(
                      context,
                    ).copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
