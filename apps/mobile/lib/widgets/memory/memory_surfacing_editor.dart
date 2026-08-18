import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_control_store.dart';
import 'package:archiveme_mobile/features/memory/memory_surfacing_mode.dart';
import 'package:archiveme_mobile/features/memory/sensitive_surfacing_policy.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Local surfacing control for evidence inspection and entry detail.
class MemorySurfacingEditor extends StatelessWidget {
  const MemorySurfacingEditor({
    required this.entry, required this.onChanged, super.key,
    this.source = 'entry_detail',
    this.cardType,
  });

  final JournalEntry entry;
  final VoidCallback onChanged;
  final String source;

  /// When set, marking Do not surface also suppresses the current card.
  final MemoryCardType? cardType;

  Future<void> _update(BuildContext context, MemorySurfacingMode mode) async {
    final display = entry.displayPresentation;
    if (mode.id == display.memorySurfacing) return;
    final updated = entry.copyWith(memorySurfacing: mode.id);
    await AppServices.instance.journalStore.update(updated);
    await PressureCheckInStore.instance().syncFromJournalEntry(updated);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.entrySurfacingChanged,
      surfacingMode: mode.id,
      source: source,
    );
    if (mode.limitsProactiveIntensity) {
      SensitiveSurfacingPolicy.trackBlocked(
        surfaceType: MemorySurfaceType.evidenceInspection,
        mode: mode,
        source: source,
      );
    }
    if (cardType != null && mode == MemorySurfacingMode.doNotSurface) {
      MemoryControlStore.markNotRelated(cardType!);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '${MemorySurfacingCopy.updatedTitle}. '
          '${MemorySurfacingCopy.updatedHelper}',
        ),
      ),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final current = MemorySurfacingMode.fromEntry(entry);
    return Column(
      key: const Key('memory_surfacing_editor'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          MemorySurfacingCopy.surfacingTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final mode in MemorySurfacingMode.values)
              ChoiceChip(
                key: Key('memory_surfacing_editor_${mode.id}'),
                label: Text(mode.label),
                selected: current == mode,
                onSelected: (_) => _update(context, mode),
              ),
          ],
        ),
      ],
    );
  }
}