import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/archive_v1/archive_v1_copy.dart';
import '../features/archive_v1/archive_v1_models.dart';
import '../theme/app_theme.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';
import '../widgets/archive_evidence_panel.dart';
import '../widgets/belief_evolution_timeline.dart';
import '../widgets/pushed_screen_shell.dart';

/// Evidence trail — why the archive believes what it believes.
class ArchiveEvidenceTrailScreen extends StatelessWidget {
  const ArchiveEvidenceTrailScreen({super.key, required this.view});

  final ArchiveV1View view;

  @override
  Widget build(BuildContext context) {
    final belief = view.belief;
    if (belief == null) {
      return PushedScreenShell(
        title: ArchiveV1Copy.evidenceTrailScreenTitle,
        body: const Center(
          child: Text(
            'Not enough evidence yet to show a belief trail.',
            style: TextStyle(color: AppTheme.muted),
          ),
        ),
      );
    }

    return PushedScreenShell(
      title: ArchiveV1Copy.evidenceTrailScreenTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            ArchiveV1Copy.whyBelieves,
            style: VoiceMemoryTypography.sectionLabelStyle(
              accent: VoiceMemoryColors.primaryIndigo,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '"${belief.statement}"',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Confidence: ${belief.confidencePercent}% · '
            '${belief.evidenceCount} recordings',
            style: const TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          const Text(
            'SUPPORTING EXCERPTS',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ArchiveEvidencePanel(
            entries: belief.supportingEntries,
            analyticsContext: 'evidence_trail',
            initiallyExpanded: true,
          ),
          if (view.evolutionTimeline.blocks.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'BELIEF EVOLUTION',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.8,
                color: AppTheme.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            BeliefEvolutionTimelineWidget(timeline: view.evolutionTimeline),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Back to Archive'),
          ),
        ],
      ),
    );
  }
}
