import 'package:archiveme_mobile/features/memory/memory_surfacing_mode.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Compact surfacing picker for the record screen entry options.
class MemorySurfacingPicker extends StatefulWidget {
  const MemorySurfacingPicker({super.key, this.entryCount = 0});

  final int entryCount;

  @override
  State<MemorySurfacingPicker> createState() => _MemorySurfacingPickerState();
}

class _MemorySurfacingPickerState extends State<MemorySurfacingPicker> {
  @override
  void initState() {
    super.initState();
    MemorySurfacingSession.notePickerSeen(entryCount: widget.entryCount);
  }

  @override
  Widget build(BuildContext context) {
    final selected = MemorySurfacingSession.selected;
    return Column(
      key: const Key('memory_surfacing_picker'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          MemorySurfacingCopy.sectionTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final mode in MemorySurfacingMode.values)
              ChoiceChip(
                key: Key('memory_surfacing_${mode.id}'),
                label: Text(mode.label),
                selected: selected == mode,
                onSelected: (_) {
                  MemorySurfacingSession.select(
                    mode,
                    entryCount: widget.entryCount,
                  );
                  setState(() {});
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(selected.helper, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}