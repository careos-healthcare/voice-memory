import 'package:flutter/material.dart';

import '../features/archive_state_delta/archive_state_snapshot.dart';
import '../theme/voicememory_colors.dart';

class ArchiveStateDeltaCardMobile extends StatelessWidget {
  const ArchiveStateDeltaCardMobile({
    super.key,
    required this.delta,
  });

  final ArchiveStateDeltaView delta;

  @override
  Widget build(BuildContext context) {
    if (!delta.hasChanges && delta.subheadline == null) {
      return const SizedBox.shrink();
    }

    return Container(
      key: const Key('archive-state-delta-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: delta.awayReturn
              ? VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.45)
              : VoiceMemoryColors.border,
        ),
        color: delta.awayReturn
            ? VoiceMemoryColors.surfaceSecondary
            : VoiceMemoryColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            delta.headline,
            style: TextStyle(
              fontSize: delta.awayReturn ? 15 : 13,
              fontWeight: FontWeight.w600,
              color: delta.awayReturn
                  ? VoiceMemoryColors.primaryIndigo
                  : VoiceMemoryColors.textPrimary,
            ),
          ),
          if (delta.subheadline != null) ...[
            const SizedBox(height: 6),
            Text(
              delta.subheadline!,
              style: const TextStyle(
                color: VoiceMemoryColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (delta.hasChanges) ...[
            const SizedBox(height: 12),
            for (final row in delta.rows) ...[
              _DeltaRow(row: row),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _DeltaRow extends StatelessWidget {
  const _DeltaRow({required this.row});

  final ArchiveStateDeltaRow row;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 0.6,
            color: VoiceMemoryColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Then ${row.then}',
          style: const TextStyle(color: VoiceMemoryColors.textSecondary),
        ),
        Text(
          'Now ${row.now}',
          style: const TextStyle(color: VoiceMemoryColors.textPrimary),
        ),
        Text(
          row.difference,
          style: const TextStyle(
            color: VoiceMemoryColors.secondaryLavender,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
