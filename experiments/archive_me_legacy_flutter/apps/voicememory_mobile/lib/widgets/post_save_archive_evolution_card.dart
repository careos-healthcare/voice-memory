import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/archive_evolution/archive_evolution_copy.dart';
import '../features/archive_evolution/archive_evolution_coordinator.dart';
import '../features/archive_evolution/archive_evolution_models.dart';
import '../features/archive_explanations/archive_explanation_navigation.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';

/// Record screen — archive updating, then one evolution line with tap to view.
class PostSaveArchiveEvolutionCard extends StatelessWidget {
  const PostSaveArchiveEvolutionCard({
    super.key,
    required this.loading,
    this.evolution,
  });

  final bool loading;
  final ArchiveEvolution? evolution;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VoiceMemoryColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VoiceMemoryColors.border),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ArchiveEvolutionCopy.updatingMessage,
                style: VoiceMemoryTypography.bodyStyle(),
              ),
            ),
          ],
        ),
      );
    }

    if (evolution == null) {
      return const SizedBox.shrink();
    }

    final evo = evolution!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.discoveryGoldBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.discoveryGoldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            evo.sectionHeadline,
            style: VoiceMemoryTypography.sectionLabelStyle(
              accent: VoiceMemoryColors.discoveryGold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            evo.headline,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              await const ArchiveEvolutionCoordinator().markOpened(evo);
              if (!context.mounted) return;
              openArchiveExplanation(
                context,
                ref: evo.insightRef,
                askCitedEntryIds: evo.evidenceIds,
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: VoiceMemoryColors.primaryIndigo,
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 44),
            ),
            child: const Text('Tap to view'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => context.go('/archive-belief'),
            child: const Text('Open archive'),
          ),
        ],
      ),
    );
  }
}
