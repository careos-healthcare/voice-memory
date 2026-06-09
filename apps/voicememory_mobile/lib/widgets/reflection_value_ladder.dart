import 'package:flutter/material.dart';

import '../models/journal_entry.dart';
import '../theme/app_theme.dart';
import '../theme/voicememory_colors.dart';

class ReflectionValueLadder extends StatelessWidget {
  const ReflectionValueLadder({super.key, required this.entries});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final count = entries.where((e) => e.transcript.trim().isNotEmpty).length;
    final stages = [
      (1, 'One data point'),
      (2, 'Possible repeat'),
      (3, 'Pattern forming'),
      (4, 'Theory under review'),
      (5, 'Evidence-based pattern review'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reflection ladder',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (final step in stages)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  count >= step.$1 ? Icons.check_circle_outline : Icons.circle_outlined,
                  size: 18,
                  color: count >= step.$1
                      ? VoiceMemoryColors.primaryIndigo
                      : AppTheme.muted,
                ),
                const SizedBox(width: 8),
                Text(
                  '${step.$1} reflection${step.$1 == 1 ? '' : 's'} → ${step.$2}',
                  style: TextStyle(
                    color: count >= step.$1
                        ? AppTheme.foreground
                        : AppTheme.muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
