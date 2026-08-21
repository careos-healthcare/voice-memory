import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/action_items/action_item_store.dart';
import 'package:archiveme_mobile/features/archive_search/archive_search_filters.dart';
import 'package:archiveme_mobile/features/archive_search/archive_search_result.dart';
import 'package:archiveme_mobile/features/collections/archive_collection.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_store.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/widgets/action_items/remember_this_button.dart';
import 'package:archiveme_mobile/widgets/collections/collection_chip.dart';
import 'package:archiveme_mobile/widgets/fact_ledger/save_as_fact_button.dart';
import 'package:flutter/material.dart';

/// One search result: the safe entry title the archive list already
/// shows, plus metadata badges — relative time bucket, context tag,
/// pinned, exact evidence, memory status, and collection chips. No
/// dates, ids, or scores.
class ArchiveSearchResultCard extends StatelessWidget {
  const ArchiveSearchResultCard({
    required this.result, super.key,
    this.onTap,
    this.onAddToCollection,
  });

  final ArchiveEntrySearchResult result;
  final VoidCallback? onTap;

  /// Opens the add-to-collection sheet for this entry when provided.
  final VoidCallback? onAddToCollection;

  @override
  Widget build(BuildContext context) {
    final badges = <String>[
      result.timeBucketLabel,
      ...result.contextTagLabels,
      if (result.threadLabel != null) result.threadLabel!,
      if (result.packLabel != null) result.packLabel!,
      if (result.entryTypeLabel != null) result.entryTypeLabel!,
      if (result.surfacingLabel != null) result.surfacingLabel!,
      if (result.preservedOriginalLabel != null) result.preservedOriginalLabel!,
      if (result.savedDetailLabel != null) result.savedDetailLabel!,
      if (result.isPinned) ArchiveSearchCopy.pinnedLabel,
      if (result.isExactEvidence) ArchiveSearchCopy.exactEvidenceLabel,
      if (result.memoryStatus != null) result.memoryStatus!.label,
    ];

    return InkWell(
      key: Key('archive_search_result_${result.entry.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(VoiceMemoryCards.radius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: VoiceMemoryCards.flat(background: AppColors.surfaceAlt),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    timelineEntryTitle(result.entry),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ArchiveMobileTypography.cardLabel(context),
                  ),
                ),
                if (onAddToCollection != null)
                  IconButton(
                    key: Key('result_add_to_collection_${result.entry.id}'),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                    tooltip: ArchiveCollectionsCopy.addToCollection,
                    onPressed: onAddToCollection,
                  ),
                RememberThisButton(
                  entry: result.entry,
                  store: ActionItemStore.instance(),
                  source: 'archive_search',
                  compact: true,
                ),
                SaveAsFactButton(
                  entry: result.entry,
                  store: FactLedgerStore.instance(),
                  source: 'archive_search',
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final badge in badges) _badge(context, badge),
                for (final name in result.collectionNames)
                  CollectionChip(name: name),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}