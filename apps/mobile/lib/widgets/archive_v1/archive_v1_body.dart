import 'dart:async';

import 'package:archiveme_mobile/core/config/theory_tracking_feature_flags.dart';
import 'package:archiveme_mobile/design/archive_mobile_spacing.dart';
import 'package:archiveme_mobile/design/empty_archive_experience.dart';
import 'package:archiveme_mobile/features/archive_deep_dive/archive_deep_dive_gate.dart';
import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/archive_theory/views/theory_page_copy.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/features/evidence_artifact/evidence_artifact_copy.dart';
import 'package:archiveme_mobile/features/evidence_artifact/evidence_proof_navigation.dart';
import 'package:archiveme_mobile/features/evidence_trail/evidence_trail_builder.dart';
import 'package:archiveme_mobile/features/evidence_trail/evidence_trail_navigation.dart';
import 'package:archiveme_mobile/features/first25/first25_user_metrics.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_belief_evolution_then_now.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_change_feed_section.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_historian_section.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_milestone_review_section.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_monthly_review_section.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_surprises_section.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_theory_agreement_section.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_theory_hero_card.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_v1_blind_spots_section.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_v1_contradictions_section.dart';
import 'package:archiveme_mobile/widgets/archive_v1/belief_lifecycle_section.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Archive V1 stack — belief moat layout with optional theory-tracking hero.
class ArchiveV1Body extends StatelessWidget {
  const ArchiveV1Body({required this.view, super.key});

  final ArchiveV1View view;

  @override
  Widget build(BuildContext context) {
    if (!view.hasMinimumEvidence) {
      return EmptyArchivePanel.needMoreEvidence();
    }

    if (TheoryTrackingFeatureFlags.enableTheoryTracking) {
      final theory = view.theory;
      if (!view.showTheoryHero || theory == null) {
        return EmptyArchivePanel.needMoreEvidence();
      }
    } else if (!view.showBeliefHero || view.belief == null) {
      return EmptyArchivePanel.needMoreEvidence();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (TheoryTrackingFeatureFlags.enableTheoryTracking &&
            view.showTheoryHero &&
            view.theory != null) ...[
          ArchiveTheoryHeroCard(
            theory: view.theory!,
            onShowMeWhy: () {
              if (!ArchiveDeepDiveGate.canOpenDeepDive(view)) return;
              unawaited(First25UserMetrics.trackDeepDiveOpened(
                surface: 'archive_theory_cta',
              ));
              unawaited(context.push('/archive-deep-dive', extra: view));
            },
            onWhyAmISeeingThis: () {
              unawaited(First25UserMetrics.trackTheoryOpened(surface: 'archive_theory'));
              final payload = buildEvidenceTrailForArchiveV1(view);
              if (payload == null) return;
              unawaited(showEvidenceTrailSheet(
                context,
                payload: payload,
                surface: 'archive_theory',
                ref: ArchiveInsightRef.belief(),
                entries: view.eligibleEntries,
              ));
            },
          ),
          const SizedBox(height: ArchiveMobileSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('archive_theory_inspect_evidence_math'),
                  onPressed: () =>
                      openEvidenceProofForArchiveV1(context, view: view),
                  child: const Text(EvidenceArtifactCopy.inspectEvidenceMath),
                ),
              ),
              const SizedBox(width: ArchiveMobileSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  key: const Key('archive_theory_share_proof_card'),
                  onPressed: () => openEvidenceProofForArchiveV1(
                    context,
                    view: view,
                    openShareOnLaunch: true,
                  ),
                  child: const Text(EvidenceArtifactCopy.shareProofCard),
                ),
              ),
            ],
          ),
          const SizedBox(height: ArchiveMobileSpacing.lg),
          ArchiveTheoryAgreementSection(theory: view.theory!),
          const SizedBox(height: ArchiveMobileSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.push('/theories'),
              child: const Text(TheoryPageCopy.title),
            ),
          ),
          const SizedBox(height: ArchiveMobileSpacing.lg),
        ],
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
          ArchiveSurprisesSection(
            surprises: view.surprises,
          ),
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
          ArchiveV1BlindSpotsSection(
            blindSpots: view.blindSpots,
          ),
        ],
      ],
    );
  }
}