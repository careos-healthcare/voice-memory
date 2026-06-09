import 'package:flutter/material.dart';

import '../features/archive_movement/archive_movement.dart';
import '../theme/voicememory_colors.dart';

class ArchiveMovementCard extends StatefulWidget {
  const ArchiveMovementCard({super.key, required this.update});

  final ArchiveMovementUpdate update;

  @override
  State<ArchiveMovementCard> createState() => _ArchiveMovementCardState();
}

class _ArchiveMovementCardState extends State<ArchiveMovementCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.update;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            u.eyebrow.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              color: VoiceMemoryColors.secondaryLavender,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            u.headline,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: VoiceMemoryColors.textPrimary,
            ),
          ),
          if (u.detailLine != null) ...[
            const SizedBox(height: 6),
            Text(
              u.detailLine!,
              style: const TextStyle(
                fontSize: 14,
                color: VoiceMemoryColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                const Text(
                  'Reason',
                  style: TextStyle(
                    fontSize: 12,
                    color: VoiceMemoryColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: VoiceMemoryColors.textSecondary,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            Text(
              u.reason,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: VoiceMemoryColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
