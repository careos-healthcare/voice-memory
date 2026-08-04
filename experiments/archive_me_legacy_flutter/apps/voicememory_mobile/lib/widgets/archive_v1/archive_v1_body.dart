import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_spacing.dart';
import '../../design/empty_archive_experience.dart';
import '../../features/archive_deep_dive/archive_deep_dive_gate.dart';
import '../../features/first25/first25_user_metrics.dart';
import '../../features/archive_explanations/explanation_models.dart';
import '../../features/archive_v1/archive_v1_models.dart';
import '../../features/evidence_trail/evidence_trail_builder.dart';
import '../../features/evidence_trail/evidence_trail_navigation.dart';
import 'archive_belief_evolution_then_now.dart';
import 'archive_change_feed_section.dart';
import 'archive_surprises_section.dart';
import 'belief_lifecycle_section.dart';
import 'archive_theory_hero_card.dart';
import 'archive_theory_agreement_section.dart';
import 'archive_historian_section.dart';
import 'archive_milestone_review_section.dart';
import 'archive_monthly_review_section.dart';
import 'archive_v1_blind_spots_section.dart';
import 'archive_v1_contradictions_section.dart';

/// Archive V1 stack — belief moat layout.
class ArchiveV1Body extends StatelessWidget {
  const ArchiveV1Body({super.key, required this.view});

  final ArchiveV1View view;

  @override
  Widget build(BuildContext context) {
    if (!view.hasMinimumEvidence) {
      return EmptyArchivePanel.needMoreEvidence();
    }

    final theory = view.theory;
    if (theory == null) {
      return EmptyArchivePanel.needMoreEvidence();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArchiveTheoryHeroCard(
          theory: theory,
          onShowMeWhy: () {
            if (!ArchiveDeepDiveGate.canOpenDeepDive(view)) return;
            First25UserMetrics.trackDeepDiveOpened(
              surface: 'archive_theory_cta',
            );
            context.push('/archive-deep-dive', extra: view);
          },
          onWhyAmISeeingThis: () {
            First25UserMetrics.trackTheoryOpened(surface: 'archive_theory');
            final payload = buildEvidenceTrailForArchiveV1(view);
            if (payload == null) return;
            showEvidenceTrailSheet(
              context,
              payload: payload,
              surface: 'archive_theory',
              ref: ArchiveInsightRef.belief(),
              entries: view.eligibleEntries,
            );
          },
        ),
        const SizedBox(height: ArchiveMobileSpacing.lg),
        ArchiveTheoryAgreementSection(theory: theory),
        const SizedBox(height: ArchiveMobileSpacing.lg),
        ArchiveMonthlyReviewSection(view: view),
        const SizedBox(height: ArchiveMobileSpacing.lg),
        ArchiveMilestoneReviewSection(view: view),
        const SizedBox(height: ArchiveMobileSpacing.lg),
        ArchiveHistorianSection(view: view),
        const SizedBox(height: ArchiveMobileSpacing.lg),
        ArchiveChangeFeedSection(
          feed: view.changeFeed,
          entries: view.eligibleEntries,
        ),
        if (view.surprises.hasObservations ||
            view.surprises.emptyMessage != null) ...[
          const SizedBox(height: ArchiveMobileSpacing.lg),
          ArchiveSurprisesSection(surprises: view.surprises),
        ],
        if (view.lifecycle.hasContent) ...[
          const SizedBox(height: ArchiveMobileSpacing.lg),
          BeliefLifecycleSection(lifecycle: view.lifecycle),
        ],
        if (view.thenNow != null) ...[
          const SizedBox(height: ArchiveMobileSpacing.lg),
          ArchiveBeliefEvolutionThenNow(thenNow: view.thenNow!),
        ],
        if (view.contradictions.isNotEmpty) ...[
          const SizedBox(height: ArchiveMobileSpacing.lg),
          ArchiveV1ContradictionsSection(
            contradictions: view.contradictions,
            entries: view.eligibleEntries,
          ),
        ],
        if (view.blindSpots.isNotEmpty) ...[
          const SizedBox(height: ArchiveMobileSpacing.lg),
          ArchiveV1BlindSpotsSection(blindSpots: view.blindSpots),
        ],
      ],
    );
  }
}
