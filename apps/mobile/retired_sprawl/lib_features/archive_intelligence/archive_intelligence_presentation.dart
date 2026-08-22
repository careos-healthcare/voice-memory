import 'dart:async';

import 'package:archiveme_mobile/core/config/theory_tracking_feature_flags.dart';
import 'package:archiveme_mobile/design/archive_mobile_spacing.dart';
import 'package:archiveme_mobile/features/archive_deep_dive/archive_deep_dive_gate.dart';
import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/archive_theory/theory_ranking_models.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_builder.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/features/evidence_trail/evidence_trail_builder.dart';
import 'package:archiveme_mobile/features/evidence_trail/evidence_trail_navigation.dart';
import 'package:archiveme_mobile/features/first25/first25_user_metrics.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_theory_agreement_section.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_theory_hero_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Entry point for theory-tracking UI on archive surfaces.
abstract final class ArchiveIntelligencePresentation {
  ArchiveIntelligencePresentation._();

  /// Returns theory-tracking chrome when enabled; otherwise an empty box.
  static Widget build({required List<JournalEntry> entries}) {
    if (!TheoryTrackingFeatureFlags.enableTheoryTracking) {
      return const SizedBox.shrink();
    }
    return ArchiveIntelligenceHome(entries: entries);
  }
}

/// Theory hero, agreement, and secondary-theory rows for the archive tab.
class ArchiveIntelligenceHome extends StatefulWidget {
  const ArchiveIntelligenceHome({required this.entries, super.key});

  final List<JournalEntry> entries;

  @override
  State<ArchiveIntelligenceHome> createState() =>
      _ArchiveIntelligenceHomeState();
}

class _ArchiveIntelligenceHomeState extends State<ArchiveIntelligenceHome> {
  ArchiveV1View? _view;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ArchiveIntelligenceHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries.length != widget.entries.length) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final view = await const ArchiveV1Builder().build(
      entries: widget.entries,
      evolutionService: AppServices.instance.beliefEvolution,
    );
    if (!mounted) return;
    setState(() {
      _view = view;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final view = _view;
    final theory = view?.theory;
    if (view == null || !view.showTheoryHero || theory == null) {
      return const SizedBox.shrink();
    }

    final secondary = view.theoryRanking?.secondaryTheories ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArchiveTheoryHeroCard(
          theory: theory,
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
        const SizedBox(height: ArchiveMobileSpacing.lg),
        ArchiveTheoryAgreementSection(theory: theory),
        if (secondary.isNotEmpty) ...[
          const SizedBox(height: ArchiveMobileSpacing.lg),
          _SecondaryTheoriesSection(theories: secondary),
        ],
      ],
    );
  }
}

class _SecondaryTheoriesSection extends StatelessWidget {
  const _SecondaryTheoriesSection({required this.theories});

  final List<RankedTheory> theories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Other theories forming', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final ranked in theories)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '· ${ranked.statement}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}