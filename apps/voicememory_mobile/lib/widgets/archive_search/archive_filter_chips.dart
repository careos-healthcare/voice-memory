import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/memory/entry_aboutness.dart';
import '../../features/memory/memory_surfacing_mode.dart';
import '../../features/archive_search/archive_search_filters.dart';
import '../../features/archive_search/archive_search_query.dart';
import '../../features/archive_packs/archive_pack.dart';
import '../../features/collections/archive_collection.dart';
import '../../features/memory/archive_thread.dart';
import '../../features/pressure_retention/pressure_context.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';

/// Archive search filter chips: relative date, memory status, context
/// tags, exact evidence, and pinned — plus "Clear filters".
///
/// Filters are metadata toggles only. Analytics carries the filter
/// *type* (date / memory_status / …), never the selected value and
/// never any query text.
class ArchiveFilterChips extends StatelessWidget {
  const ArchiveFilterChips({
    super.key,
    required this.query,
    required this.onChanged,
    this.availableContextTags = const [],
    this.availableCollections = const [],
    this.availableThreads = const [],
    this.availablePacks = const [],
  });

  final ArchiveEntrySearchQuery query;
  final ValueChanged<ArchiveEntrySearchQuery> onChanged;
  final List<PressureContext> availableContextTags;

  /// Collections shown as filter chips. Names appear in the UI only;
  /// toggling fires a fixed event with no name attached.
  final List<ArchiveCollection> availableCollections;

  /// Archive threads shown as filter chips. Names appear in the UI only.
  final List<ArchiveThread> availableThreads;

  /// Archive packs shown as filter chips. Names appear in the UI only.
  final List<ArchivePack> availablePacks;

  void _update(ArchiveEntrySearchQuery next, String filterType) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archiveSearchFilterUsed,
      filterType: filterType,
    );
    onChanged(next);
  }

  void _toggleCollection(ArchiveCollection collection) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.collectionFilterUsed,
    );
    onChanged(
      query.copyWith(
        collectionId: () =>
            query.collectionId == collection.id ? null : collection.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('archive_filter_chips'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              ArchiveSearchCopy.filterHeading,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const Spacer(),
            if (query.hasActiveFilters)
              TextButton(
                key: const Key('archive_clear_filters'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: AppColors.textSecondary,
                ),
                onPressed: () => _update(
                  query.clearedFilters(),
                  ArchiveSearchFilterType.clear,
                ),
                child: Text(ArchiveSearchCopy.clearFilters),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final date in ArchiveDateFilter.values)
              _chip(
                context,
                key: Key('archive_filter_date_${date.id}'),
                label: date.label,
                selected: query.dateFilter == date,
                onTap: () => _update(
                  query.copyWith(
                    dateFilter: () => query.dateFilter == date ? null : date,
                  ),
                  ArchiveSearchFilterType.date,
                ),
              ),
            for (final status in ArchiveMemoryStatus.values)
              _chip(
                context,
                key: Key('archive_filter_status_${status.id}'),
                label: status.label,
                selected: query.memoryStatus == status,
                onTap: () => _update(
                  query.copyWith(
                    memoryStatus: () =>
                        query.memoryStatus == status ? null : status,
                  ),
                  ArchiveSearchFilterType.memoryStatus,
                ),
              ),
            for (final aboutness in EntryAboutness.values)
              _chip(
                context,
                key: Key('archive_filter_entry_type_${aboutness.id}'),
                label: aboutness.label,
                selected: query.entryAboutnessId == aboutness.id,
                onTap: () => _update(
                  query.copyWith(
                    entryAboutnessId: () =>
                        query.entryAboutnessId == aboutness.id
                        ? null
                        : aboutness.id,
                  ),
                  ArchiveSearchFilterType.entryType,
                ),
              ),
            for (final mode in MemorySurfacingMode.values)
              _chip(
                context,
                key: Key('archive_filter_surfacing_${mode.id}'),
                label: mode.label,
                selected: query.memorySurfacingId == mode.id,
                onTap: () => _update(
                  query.copyWith(
                    memorySurfacingId: () =>
                        query.memorySurfacingId == mode.id ? null : mode.id,
                  ),
                  ArchiveSearchFilterType.surfacing,
                ),
              ),
            for (final tag in availableContextTags)
              _chip(
                context,
                key: Key('archive_filter_tag_${tag.id}'),
                label: tag.label,
                selected: query.contextTagId == tag.id,
                onTap: () => _update(
                  query.copyWith(
                    contextTagId: () =>
                        query.contextTagId == tag.id ? null : tag.id,
                  ),
                  ArchiveSearchFilterType.contextTag,
                ),
              ),
            _chip(
              context,
              key: const Key('archive_filter_exact_evidence'),
              label: ArchiveSearchCopy.exactEvidenceLabel,
              selected: query.exactEvidenceOnly,
              onTap: () => _update(
                query.copyWith(exactEvidenceOnly: !query.exactEvidenceOnly),
                ArchiveSearchFilterType.exactEvidence,
              ),
            ),
            for (final collection in availableCollections)
              _chip(
                context,
                key: Key('archive_filter_collection_${collection.id}'),
                label: collection.name,
                selected: query.collectionId == collection.id,
                onTap: () => _toggleCollection(collection),
              ),
            for (final thread in availableThreads)
              _chip(
                context,
                key: Key('archive_filter_thread_${thread.id}'),
                label: thread.name,
                selected: query.threadId == thread.id,
                onTap: () => _update(
                  query.copyWith(
                    threadId: () =>
                        query.threadId == thread.id ? null : thread.id,
                  ),
                  ArchiveSearchFilterType.thread,
                ),
              ),
            for (final pack in availablePacks)
              _chip(
                context,
                key: Key('archive_filter_pack_${pack.id}'),
                label: pack.name,
                selected: query.packId == pack.id,
                onTap: () => _update(
                  query.copyWith(
                    packId: () => query.packId == pack.id ? null : pack.id,
                  ),
                  ArchiveSearchFilterType.pack,
                ),
              ),
            _chip(
              context,
              key: const Key('archive_filter_preserved_original'),
              label: ArchiveSearchCopy.preservedOriginalLabel,
              selected: query.preservedOriginalOnly,
              onTap: () => _update(
                query.copyWith(
                  preservedOriginalOnly: !query.preservedOriginalOnly,
                ),
                ArchiveSearchFilterType.preservedOriginal,
              ),
            ),
            _chip(
              context,
              key: const Key('archive_filter_saved_details'),
              label: ArchiveSearchCopy.savedDetailsLabel,
              selected: query.savedDetailsOnly,
              onTap: () => _update(
                query.copyWith(savedDetailsOnly: !query.savedDetailsOnly),
                ArchiveSearchFilterType.savedDetails,
              ),
            ),
            _chip(
              context,
              key: const Key('archive_filter_pinned'),
              label: ArchiveSearchCopy.pinnedLabel,
              selected: query.pinnedOnly,
              onTap: () => _update(
                query.copyWith(pinnedOnly: !query.pinnedOnly),
                ArchiveSearchFilterType.pinned,
              ),
            ),
            _chip(
              context,
              key: const Key('archive_filter_archived'),
              label: ArchiveSearchCopy.archivedLabel,
              selected: query.archivedOnly,
              onTap: () => _update(
                query.copyWith(archivedOnly: !query.archivedOnly),
                ArchiveSearchFilterType.archived,
              ),
            ),
            _chip(
              context,
              key: const Key('archive_filter_action_items'),
              label: ArchiveSearchCopy.actionItemsLabel,
              selected: query.actionItemsOnly,
              onTap: () => _update(
                query.copyWith(actionItemsOnly: !query.actionItemsOnly),
                ArchiveSearchFilterType.actionItems,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chip(
    BuildContext context, {
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      key: key,
      label: Text(
        label,
        style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
          color: selected ? AppColors.accentPrimary : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: AppColors.surfaceAlt,
      selectedColor: AppColors.accentLight,
      side: BorderSide(color: AppColors.borderSubtle),
      visualDensity: VisualDensity.compact,
    );
  }
}
