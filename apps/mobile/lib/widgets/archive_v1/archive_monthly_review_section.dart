import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/features/archive_discovery_share/archive_discovery_share_moments.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_copy.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_models.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_pro_gate.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_service.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_store.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/archive_discovery_share/share_discovery_button.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_intelligence_upgrade_card.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Archive Monthly Review — Pro GPT synthesis (deterministic archive unchanged).
class ArchiveMonthlyReviewSection extends StatefulWidget {
  const ArchiveMonthlyReviewSection({required this.view, super.key});

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
      // `BillingService.loadEntitlements` delegates to `BillingNotifier`, which
      // writes `state` before its first await, so calling it straight from
      // `initState` mutates a provider mid-build. Run it once the frame is done.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_load());
      });
    } else {
      _loading = false;
    }
  }

  @override
  void didUpdateWidget(covariant ArchiveMonthlyReviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view != widget.view) {
      // `didUpdateWidget` also runs inside the build phase, so the reload has
      // to be deferred for the same reason as the one in `initState`.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_load());
      });
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = AppServices.instance;
    final entitlements = await s.billing.loadEntitlements();

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
      repository: appProviderContainer.read(archiveSynthesisRepositoryProvider),
      deviceIds: s.deviceIds,
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
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              ArchiveSynthesisCopy.loading,
              style: TextStyle(color: AppTheme.muted, fontSize: 13),
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
                const Text(
                  ArchiveSynthesisCopy.cachedBadge,
                  style: TextStyle(color: AppTheme.muted, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            ArchiveSynthesisCopy.pilotNote,
            style: TextStyle(
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
    final shareCard = ArchiveDiscoveryShareMoments.fromMonthlyConclusion(
      conclusion: item,
      review: review,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.statement,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${item.confidencePercent}% · ${item.evidence.length} ${ArchiveSynthesisCopy.evidenceCountLabel}',
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '${ArchiveSynthesisCopy.uncertaintyPrefix}${item.uncertaintyNote}',
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              height: 1.35,
              fontStyle: FontStyle.italic,
            ),
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