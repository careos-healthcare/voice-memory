import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/archive_v1/archive_v1_copy.dart';
import '../../features/archive_v1/archive_v1_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/voicememory_colors.dart';
import '../../theme/voicememory_typography.dart';

class ArchiveV1BlindSpotsSection extends StatelessWidget {
  const ArchiveV1BlindSpotsSection({
    super.key,
    required this.blindSpots,
  });

  final List<ArchiveV1BlindSpot> blindSpots;

  @override
  Widget build(BuildContext context) {
    if (blindSpots.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ArchiveV1Copy.blindSpotsTitle,
          style: VoiceMemoryTypography.sectionLabelStyle(
            accent: VoiceMemoryColors.blindSpotAmber,
          ),
        ),
        const SizedBox(height: 12),
        for (final spot in blindSpots) ...[
          _BlindSpotCard(
            spot: spot,
            onOpenEntry: (id) => context.push('/entry/$id'),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _BlindSpotCard extends StatelessWidget {
  const _BlindSpotCard({
    required this.spot,
    required this.onOpenEntry,
  });

  final ArchiveV1BlindSpot spot;
  final void Function(String entryId) onOpenEntry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: VoiceMemoryColors.blindSpotAmber.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            spot.headline,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            spot.observation,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on ${spot.evidenceCount} '
            '${spot.evidenceCount == 1 ? 'recording' : 'recordings'} · '
            'Confidence: ${spot.confidence}%',
            style: const TextStyle(fontSize: 11, color: AppTheme.muted),
          ),
          if (spot.entryIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => onOpenEntry(spot.entryIds.first),
              child: const Text('View supporting recording'),
            ),
          ],
        ],
      ),
    );
  }
}
