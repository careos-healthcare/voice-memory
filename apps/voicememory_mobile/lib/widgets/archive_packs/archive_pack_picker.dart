import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_packs/archive_pack.dart';
import '../../features/archive_packs/archive_pack_store.dart';
import '../../features/archive_packs/entry_pack_scope.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'create_archive_pack_sheet.dart';

/// Pack picker for the entry being saved — under Entry options.
class ArchivePackPicker extends StatefulWidget {
  const ArchivePackPicker({super.key, required this.packs, this.entryCount});

  final List<ArchivePack> packs;
  final int? entryCount;

  @override
  State<ArchivePackPicker> createState() => _ArchivePackPickerState();
}

class _ArchivePackPickerState extends State<ArchivePackPicker> {
  @override
  void initState() {
    super.initState();
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archivePacksOpened,
      source: 'record_picker',
      packCountBucket: ActivationFunnelAnalytics.resultCountBucket(
        widget.packs.length,
      ),
      oncePerSession: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = EntryPackScopeSession.selectedScope;
    return Column(
      key: const Key('archive_pack_picker'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ArchivePacksCopy.saveToPack,
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final packScope in EntryPackScope.values)
          RadioListTile<EntryPackScope>(
            key: Key('entry_pack_scope_${packScope.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(packScope.label),
            value: packScope,
            groupValue: scope,
            onChanged: (value) {
              if (value == null) return;
              EntryPackScopeSession.selectScope(value);
              setState(() {});
            },
          ),
        if (scope == EntryPackScope.existingPack) ...[
          if (widget.packs.isEmpty)
            Text(
              ArchivePacksCopy.emptyHelper,
              key: const Key('archive_pack_empty_state'),
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final pack in widget.packs)
                  ChoiceChip(
                    key: Key('entry_pack_choice_${pack.id}'),
                    label: Text(pack.name),
                    selected: EntryPackScopeSession.selectedPackId == pack.id,
                    onSelected: (_) {
                      EntryPackScopeSession.selectExistingPack(pack.id);
                      setState(() {});
                    },
                  ),
              ],
            ),
        ],
        if (scope == EntryPackScope.newPack)
          TextButton(
            key: const Key('entry_pack_new_sheet'),
            onPressed: () async {
              final name = await showCreateArchivePackSheet(context);
              if (name != null && name.isNotEmpty) {
                EntryPackScopeSession.setPendingNewPackName(name);
                setState(() {});
              }
            },
            child: Text(ArchivePacksCopy.newPack),
          ),
      ],
    );
  }
}
