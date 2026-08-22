import 'package:archiveme_mobile/features/archive_evidence/archive_belief_thread_copy.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Three one-tap entry starters for the Record screen.
class EntryDirectionStarters extends StatelessWidget {
  const EntryDirectionStarters({
    required this.onSelect, super.key,
    this.selectedPrompt,
  });

  final ValueChanged<String> onSelect;
  final String? selectedPrompt;

  static const repeatedPrompt =
      'Something that may have repeated today — say it plainly.';
  static const changedPrompt =
      'Something that changed today — say what feels different.';
  static const avoidedPrompt =
      'Something I avoided today — say what you noticed.';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            _StarterChip(
              key: const Key('entry_starter_repeated'),
              label: ArchiveBeliefThreadCopy.entryStarterRepeated,
              selected: selectedPrompt == repeatedPrompt,
              onTap: () => onSelect(repeatedPrompt),
            ),
            _StarterChip(
              key: const Key('entry_starter_changed'),
              label: ArchiveBeliefThreadCopy.entryStarterChanged,
              selected: selectedPrompt == changedPrompt,
              onTap: () => onSelect(changedPrompt),
            ),
            _StarterChip(
              key: const Key('entry_starter_avoided'),
              label: ArchiveBeliefThreadCopy.entryStarterAvoided,
              selected: selectedPrompt == avoidedPrompt,
              onTap: () => onSelect(avoidedPrompt),
            ),
          ],
        ),
      ],
    );
  }
}

class _StarterChip extends StatelessWidget {
  const _StarterChip({
    required this.label, required this.selected, required this.onTap, super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
  }
}