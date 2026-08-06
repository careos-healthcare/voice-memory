import 'package:flutter/material.dart';

import '../../features/memory/next_entry_fresh_mode.dart';
import '../../features/memory/memory_control_model.dart';

/// One-shot fresh mode toggle for the record screen entry options.
class FreshNextEntryCard extends StatefulWidget {
  const FreshNextEntryCard({super.key});

  @override
  State<FreshNextEntryCard> createState() => _FreshNextEntryCardState();
}

class _FreshNextEntryCardState extends State<FreshNextEntryCard> {
  @override
  Widget build(BuildContext context) {
    if (!NextEntryFreshMode.isRelevant) {
      return const SizedBox.shrink();
    }

    return SwitchListTile(
      key: const Key('fresh_next_entry_control'),
      contentPadding: EdgeInsets.zero,
      title: Text(
        MemoryControlCopy.freshNextEntryLabel,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(MemoryControlCopy.freshNextEntryHelper),
      value: NextEntryFreshMode.enabledForNextSave,
      onChanged: (value) {
        setState(() {
          if (value) {
            NextEntryFreshMode.enable();
          } else {
            NextEntryFreshMode.cancel();
          }
        });
      },
    );
  }
}
