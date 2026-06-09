import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/archive_v1/archive_v1_copy.dart';
import '../../features/archive_v1/archive_v1_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/voicememory_colors.dart';
import '../../features/archive_explanations/explanation_models.dart';
import '../../features/evidence_trail/evidence_trail_builder.dart';
import '../../features/evidence_trail/evidence_trail_navigation.dart';
import '../../models/journal_entry.dart';
import '../../theme/voicememory_typography.dart';
import '../../features/archive_discovery_share/archive_discovery_share_moments.dart';
import '../archive_discovery_share/share_discovery_button.dart';
import '../evidence_trail/why_am_i_seeing_this_button.dart';

class ArchiveV1ContradictionsSection extends StatelessWidget {
  const ArchiveV1ContradictionsSection({
    super.key,
    required this.contradictions,
    required this.entries,
  });

  final List<ArchiveV1Contradiction> contradictions;
  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (contradictions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ArchiveV1Copy.contradictionsTitle,
          style: VoiceMemoryTypography.sectionLabelStyle(
            accent: VoiceMemoryColors.contradictionRose,
          ),
        ),
        const SizedBox(height: 12),
        for (final c in contradictions) ...[
          _ContradictionCard(
            contradiction: c,
            entries: entries,
            onOpenEntry: (id) => context.push('/entry/$id'),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ContradictionCard extends StatelessWidget {
  const _ContradictionCard({
    required this.contradiction,
    required this.entries,
    required this.onOpenEntry,
  });

  final ArchiveV1Contradiction contradiction;
  final List<JournalEntry> entries;
  final void Function(String entryId) onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final c = contradiction;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: VoiceMemoryColors.contradictionRose.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You say:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            c.youSay,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 10),
          const Text(
            'But:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            c.but,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Confidence: ${c.confidenceScore}%',
            style: const TextStyle(fontSize: 11, color: AppTheme.muted),
          ),
          WhyAmISeeingThisButton(
            compact: true,
            onPressed: () {
              final payload = buildEvidenceTrailForV1Contradiction(
                contradiction: c,
                entries: entries,
              );
              if (payload == null) return;
              showEvidenceTrailSheet(
                context,
                payload: payload,
                surface: 'archive_contradiction',
                ref: c.entryIds.length >= 2
                    ? ArchiveInsightRef.contradiction(
                        entryIdA: c.entryIds[0],
                        entryIdB: c.entryIds[1],
                      )
                    : null,
                entries: entries,
              );
            },
          ),
          if (c.entryIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final id in c.entryIds.take(3))
                  TextButton(
                    onPressed: () => onOpenEntry(id),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('View recording'),
                  ),
              ],
            ),
          ],
          if (ArchiveDiscoveryShareMoments.fromContradiction(c) case final shareCard?) ...[
            const SizedBox(height: 4),
            ShareDiscoveryButton(
              card: shareCard,
              surface: 'archive_contradiction',
            ),
          ],
        ],
      ),
    );
  }
}
