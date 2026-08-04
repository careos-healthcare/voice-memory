import 'package:flutter/material.dart';

import '../../features/memory/entry_aboutness.dart';
import '../../theme/app_spacing.dart';

/// Compact aboutness picker for the record screen entry options.
class EntryAboutnessPicker extends StatefulWidget {
  const EntryAboutnessPicker({super.key, this.entryCount = 0});

  final int entryCount;

  @override
  State<EntryAboutnessPicker> createState() => _EntryAboutnessPickerState();
}

class _EntryAboutnessPickerState extends State<EntryAboutnessPicker> {
  @override
  void initState() {
    super.initState();
    EntryAboutnessSession.notePickerSeen(entryCount: widget.entryCount);
  }

  @override
  Widget build(BuildContext context) {
    final selected = EntryAboutnessSession.selected;
    return Column(
      key: const Key('entry_aboutness_picker'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          EntryAboutnessCopy.sectionTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final aboutness in EntryAboutness.values)
              ChoiceChip(
                key: Key('entry_aboutness_${aboutness.id}'),
                label: Text(aboutness.label),
                selected: selected == aboutness,
                onSelected: (_) {
                  EntryAboutnessSession.select(
                    aboutness,
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
