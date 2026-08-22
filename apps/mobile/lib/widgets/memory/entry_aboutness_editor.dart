import 'package:archiveme_mobile/features/memory/entry_aboutness.dart';
import 'package:archiveme_mobile/features/memory/not_about_me_policy.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Entry detail control to change entry type after save.
class EntryAboutnessEditor extends StatelessWidget {
  const EntryAboutnessEditor({
    required this.entry, required this.onChanged, super.key,
  });

  final JournalEntry entry;
  final VoidCallback onChanged;

  Future<void> _update(BuildContext context, EntryAboutness aboutness) async {
    if (aboutness.id == entry.displayPresentation.entryAboutness) return;
    final updated = entry.copyWith(entryAboutness: aboutness.id);
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
    final current = EntryAboutness.fromId(entry.displayPresentation.entryAboutness);
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