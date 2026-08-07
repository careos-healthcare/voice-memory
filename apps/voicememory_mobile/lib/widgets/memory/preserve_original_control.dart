import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/memory/curated_memory_marker.dart';
import '../../features/pressure_retention/pressure_check_in_store.dart';
import '../../models/journal_entry.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../services/app_services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Pre-save / entry-detail "Preserve original" toggle.
class PreserveOriginalControl extends StatefulWidget {
  const PreserveOriginalControl({
    super.key,
    this.entryCount,
    this.selected,
    this.onChanged,
    this.source = 'record',
  });

  final int? entryCount;
  final bool? selected;
  final ValueChanged<bool>? onChanged;
  final String source;

  @override
  State<PreserveOriginalControl> createState() =>
      _PreserveOriginalControlState();
}

class _PreserveOriginalControlState extends State<PreserveOriginalControl> {
  bool get _selected =>
      widget.selected ?? PreserveOriginalSession.selectedForNextSave;

  void _toggle() {
    final next = !_selected;
    if (widget.onChanged != null) {
      widget.onChanged!(next);
    } else {
      PreserveOriginalSession.select(next, entryCount: widget.entryCount ?? 0);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return InkWell(
      key: const Key('preserve_original_control'),
      onTap: _toggle,
      borderRadius: BorderRadius.circular(VoiceMemoryCards.radius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: VoiceMemoryCards.flat(
          background: selected ? AppColors.accentLight : AppColors.surfaceAlt,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                key: const Key('preserve_original_toggle'),
                selected
                    ? Icons.check_box_outlined
                    : Icons.check_box_outline_blank,
                size: 20,
                color: selected
                    ? AppColors.accentPrimary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CuratedMemoryCopy.preserveOriginalLabel,
                    style: ArchiveMobileTypography.cardLabel(context),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CuratedMemoryCopy.preserveOriginalHelper,
                    style: ArchiveMobileTypography.responsiveHelper(
                      context,
                    ).copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Entry-detail preserve toggle with persistence.
class PreserveOriginalEditor extends StatelessWidget {
  const PreserveOriginalEditor({
    super.key,
    required this.entry,
    required this.onChanged,
  });

  final JournalEntry entry;
  final VoidCallback onChanged;

  Future<void> _update(bool enabled) async {
    if (enabled == entry.preserveOriginal) return;
    final updated = entry.copyWith(preserveOriginal: enabled);
    await AppServices.instance.journalStore.update(updated);
    await PressureCheckInStore.instance().syncFromJournalEntry(updated);
    ActivationFunnelAnalytics.track(
      enabled
          ? ActivationFunnelAnalytics.preserveOriginalSelected
          : ActivationFunnelAnalytics.preserveOriginalRemoved,
      source: 'entry_detail',
      preservationSource: CuratedPreservationSource.manual.id,
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return PreserveOriginalControl(
      selected: entry.preserveOriginal,
      onChanged: _update,
      source: 'entry_detail',
    );
  }
}
