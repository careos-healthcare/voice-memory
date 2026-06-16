import 'package:flutter/material.dart';

import '../features/archive_evolution/archive_evolution_coordinator.dart';
import '../features/archive_evolution/archive_evolution_copy.dart';
import '../features/archive_evolution/archive_evolution_models.dart';
import '../features/archive_explanations/archive_explanation_navigation.dart';
import '../models/journal_entry.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';

/// Single living-archive hero — one evolution event and Why CTA.
class ArchiveEvolutionCard extends StatelessWidget {
  const ArchiveEvolutionCard({
    super.key,
    required this.evolution,
    required this.entries,
    this.onDismissed,
  });

  final ArchiveEvolution evolution;
  final List<JournalEntry> entries;
  final VoidCallback? onDismissed;

  Future<void> _openWhy(BuildContext context) async {
    await const ArchiveEvolutionCoordinator().markOpened(evolution);
    if (!context.mounted) return;
    openArchiveExplanation(
      context,
      ref: evolution.insightRef,
      askCitedEntryIds: evolution.evidenceIds,
    );
  }

  Future<void> _dismiss() async {
    await const ArchiveEvolutionCoordinator().markIgnored(evolution);
    onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.discoveryGoldBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VoiceMemoryColors.discoveryGoldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  evolution.sectionHeadline,
                  style: VoiceMemoryTypography.sectionLabelStyle(
                    accent: VoiceMemoryColors.discoveryGold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: VoiceMemoryColors.textSecondary,
                tooltip: 'Not now',
                onPressed: _dismiss,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            evolution.headline,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              height: 1.35,
            ),
          ),
          if (evolution.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              evolution.summary,
              style: VoiceMemoryTypography.bodyStyle(
                color: VoiceMemoryColors.textSecondary,
              ).copyWith(height: 1.45),
            ),
          ],
          if (evolution.evidenceIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              evolution.evidenceIds.length == 1
                  ? '1 supporting recording'
                  : '${evolution.evidenceIds.length} supporting recordings',
              style: VoiceMemoryTypography.metadataStyle(),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _openWhy(context),
            style: FilledButton.styleFrom(
              backgroundColor: VoiceMemoryColors.primaryIndigo,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Why?'),
          ),
        ],
      ),
    );
  }
}

/// Discovery streak + last archive update — anticipation below the hero.
class ArchiveEvolutionAnticipationRow extends StatelessWidget {
  const ArchiveEvolutionAnticipationRow({
    super.key,
    required this.discoveryStreakDays,
    required this.lastArchiveUpdateAt,
  });

  final int discoveryStreakDays;
  final DateTime? lastArchiveUpdateAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (discoveryStreakDays > 0) ...[
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_outlined,
                color: VoiceMemoryColors.discoveryGold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Discovery streak: $discoveryStreakDays '
                '${discoveryStreakDays == 1 ? 'day' : 'days'}',
                style: VoiceMemoryTypography.bodyStyle(),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Text(
          ArchiveEvolutionCopy.lastArchiveUpdateLabel(lastArchiveUpdateAt),
          style: VoiceMemoryTypography.metadataStyle(
            color: VoiceMemoryColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
