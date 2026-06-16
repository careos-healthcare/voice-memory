import 'package:flutter/material.dart';

import '../../features/memory/entry_aboutness.dart';
import '../../features/memory/not_about_me_policy.dart';
import '../../features/pressure_retention/pressure_check_in_store.dart';
import '../../models/journal_entry.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../services/app_services.dart';
import '../../theme/app_spacing.dart';

/// Entry detail control to change entry type after save.
class EntryAboutnessEditor extends StatelessWidget {
  const EntryAboutnessEditor({
    super.key,
    required this.entry,
    required this.onChanged,
  });

  final JournalEntry entry;
  final VoidCallback onChanged;

  Future<void> _update(BuildContext context, EntryAboutness aboutness) async {
    if (aboutness.id == entry.entryAboutness) return;
    final updated = JournalEntry(
      id: entry.id,
      createdAt: entry.createdAt,
      transcript: entry.transcript,
      durationSeconds: entry.durationSeconds,
      reflection: entry.reflection,
      syncStatus: entry.syncStatus,
      localAudioPath: entry.localAudioPath,
      treatAsNew: entry.treatAsNew,
      connectionApproved: entry.connectionApproved,
      keepExactDetails: entry.keepExactDetails,
      keepSeparate: entry.keepSeparate,
      archiveThreadId: entry.archiveThreadId,
      archivePackId: entry.archivePackId,
      isPinned: entry.isPinned,
      pinnedAt: entry.pinnedAt,
      isArchived: entry.isArchived,
      archivedAt: entry.archivedAt,
      entryAboutness: aboutness.id,
      memorySurfacing: entry.memorySurfacing,
    );
    await AppServices.instance.journalStore.update(updated);
    await PressureCheckInStore.instance().syncFromJournalEntry(updated);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.entryAboutnessChanged,
      entryAboutness: aboutness.id,
      source: 'entry_detail',
    );
    if (NotAboutMePolicy.blocksPersonalMemoryClaims(aboutness)) {
      NotAboutMePolicy.trackBlocked(source: 'entry_detail');
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final current = EntryAboutness.fromId(entry.entryAboutness);
    return Column(
      key: const Key('entry_aboutness_editor'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          EntryAboutnessCopy.entryTypeTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final aboutness in EntryAboutness.values)
              ChoiceChip(
                key: Key('entry_detail_aboutness_${aboutness.id}'),
                label: Text(aboutness.label),
                selected: current == aboutness,
                onSelected: (_) => _update(context, aboutness),
              ),
          ],
        ),
      ],
    );
  }
}
