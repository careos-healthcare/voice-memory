import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/archive_evidence/archive_evidence.dart';
import '../../features/archive_synthesis/archive_synthesis_copy.dart';
import '../../features/archive_synthesis/archive_synthesis_models.dart';
import '../../features/archive_synthesis/archive_synthesis_pro_gate.dart';
import '../../config/app_config.dart';
import '../../features/archive_synthesis/archive_synthesis_store.dart';
import '../../features/archive_synthesis/archive_synthesis_service.dart';
import '../../features/archive_v1/archive_v1_models.dart';
import '../../services/app_services.dart';
import '../../theme/app_theme.dart';
import '../../theme/voicememory_colors.dart';
import '../../theme/voicememory_typography.dart';
import '../../features/archive_discovery_share/archive_discovery_share_moments.dart';
import '../../features/explainable_conclusion/explainable_conclusion_mappers.dart';
import '../../features/explainable_conclusion/explainable_conclusion_widgets.dart';
import '../archive_discovery_share/share_discovery_button.dart';
import 'archive_intelligence_upgrade_card.dart';

/// Archive Monthly Review — Pro GPT synthesis (deterministic archive unchanged).
class ArchiveMonthlyReviewSection extends StatefulWidget {
  const ArchiveMonthlyReviewSection({super.key, required this.view});

  final ArchiveV1View view;

  @override
  State<ArchiveMonthlyReviewSection> createState() =>
      _ArchiveMonthlyReviewSectionState();
}

class _ArchiveMonthlyReviewSectionState
    extends State<ArchiveMonthlyReviewSection> {
  ArchiveSynthesisLoadResult? _result;
  bool _loading = true;
  bool _showUpgrade = false;

  @override
  void initState() {
    super.initState();
    if (AppConfig.enableGpt5ArchiveSynthesis) {
      _load();
    } else {
      _loading = false;
    }
  }

  @override
  void didUpdateWidget(covariant ArchiveMonthlyReviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view != widget.view) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = AppServices.instance;
    final entitlements = await s.subscriptionRepository.refresh();

    if (!ArchiveSynthesisProGate.canAccessArchiveIntelligence(entitlements)) {
      if (!mounted) return;
      setState(() {
        _showUpgrade = ArchiveSynthesisProGate.shouldShowUpgradeTeaser(
          widget.view,
        );
        _result = null;
        _loading = false;
      });
      return;
    }

    final service = ArchiveSynthesisService(
      store: ArchiveSynthesisStore(s.prefs),
      api: s.journalSyncApi,
      deviceIds: s.deviceIds,
      history: s.explainabilityHistoryStore,
      hybridAiRouter: s.hybridAiRouter,
    );
    final userId = s.auth.currentSession?.userId;
    final result = await service.loadMonthly(
      view: widget.view,
      entitlements: entitlements,
      userId: userId,
    );
    if (!mounted) return;
    setState(() {
      _showUpgrade = false;
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.enableGpt5ArchiveSynthesis) {
      return const SizedBox.shrink();
    }
    if (_loading) {
      return _panel(
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              ArchiveSynthesisCopy.loading,
              style: const TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_showUpgrade) {
      return ArchiveIntelligenceUpgradeCard(view: widget.view);
    }

    final result = _result;
    if (result == null || !result.showSection || result.review == null) {
      return const SizedBox.shrink();
    }

    final review = result.review!;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ArchiveSynthesisCopy.sectionTitle,
                  style: VoiceMemoryTypography.sectionTitleStyle(),
                ),
              ),
              if (result.fromCache)
                Text(
                  ArchiveSynthesisCopy.cachedBadge,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ArchiveSynthesisCopy.pilotNote,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (review.whatChanged.isNotEmpty)
            _section(
              ArchiveSynthesisCopy.whatChangedTitle,
              review.whatChanged,
              review,
            ),
          if (review.emergingTheories.isNotEmpty)
            _section(
              ArchiveSynthesisCopy.emergingTitle,
              review.emergingTheories,
              review,
            ),
          if (review.fadingTheories.isNotEmpty)
            _section(
              ArchiveSynthesisCopy.fadingTitle,
              review.fadingTheories,
              review,
            ),
          if (review.surprises.isNotEmpty)
            _section(
              ArchiveSynthesisCopy.surprisesTitle,
              review.surprises,
              review,
            ),
          if (review.biggestSurprise != null)
            _section(ArchiveSynthesisCopy.biggestSurpriseTitle, [
              review.biggestSurprise!,
            ], review),
          if (review.strongestContradiction != null)
            _section(ArchiveSynthesisCopy.strongestContradictionTitle, [
              review.strongestContradiction!,
            ], review),
          if (review.evidenceFor.isNotEmpty)
            _section(
              ArchiveSynthesisCopy.evidenceForTitle,
              review.evidenceFor,
              review,
            ),
          if (review.evidenceAgainst.isNotEmpty)
            _section(
              ArchiveSynthesisCopy.evidenceAgainstTitle,
              review.evidenceAgainst,
              review,
            ),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    List<ArchiveSynthesisConclusion> items,
    ArchiveMonthlyReview review,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: VoiceMemoryTypography.sectionLabelStyle()),
          const SizedBox(height: 8),
          ...items.map((item) => _conclusionTile(item, review: review)),
        ],
      ),
    );
  }

  Widget _conclusionTile(
    ArchiveSynthesisConclusion item, {
    required ArchiveMonthlyReview review,
  }) {
    final transcripts = {
      for (final entry in archiveEligibleEvidenceEntries(
        widget.view.eligibleEntries,
      ))
        entry.id: entry.transcript,
    };
    final gated = ExplainableConclusionMappers.fromArchiveSynthesis(
      source: item,
      canonicalTranscripts: transcripts,
    ).gated(transcripts);
    if (gated == null) return const SizedBox.shrink();
    final shareCard = ArchiveDiscoveryShareMoments.fromMonthlyConclusion(
      conclusion: item,
      review: review,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExplainableConclusionCard(
            conclusion: gated,
            onEvidenceSelected: (context, citation) =>
                context.push('/entry/${citation.entryId}'),
            onShowHistory: () async {
              final entries = await AppServices
                  .instance
                  .explainabilityHistoryStore
                  .byConclusionId(gated.value.id);
              if (!mounted) return;
              await ExplainableHistorySheet.show(
                context,
                entries: entries,
                canonicalTranscripts: transcripts,
                onEvidenceSelected: (context, citation) =>
                    context.push('/entry/${citation.entryId}'),
              );
            },
          ),
          if (shareCard != null) ...[
            const SizedBox(height: 4),
            ShareDiscoveryButton(
              card: shareCard,
              surface: 'archive_monthly_review',
            ),
          ],
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: child,
    );
  }
}
