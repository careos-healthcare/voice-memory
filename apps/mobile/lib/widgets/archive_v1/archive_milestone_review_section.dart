import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
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
import 'package:archiveme_mobile/widgets/archive_v1/archive_intelligence_upgrade_card.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Permanent GPT milestone reviews — Pro only.
class ArchiveMilestoneReviewSection extends StatefulWidget {
  const ArchiveMilestoneReviewSection({required this.view, super.key});

  final ArchiveV1View view;

  @override
  State<ArchiveMilestoneReviewSection> createState() =>
      _ArchiveMilestoneReviewSectionState();
}

class _ArchiveMilestoneReviewSectionState
    extends State<ArchiveMilestoneReviewSection> {
  List<ArchiveMilestoneReview> _reviews = const [];
  bool _loading = true;
  bool _showUpgrade = false;

  @override
  void initState() {
    super.initState();
    if (AppConfig.enableGpt5ArchiveSynthesis) {
      unawaited(_load());
    } else {
      _loading = false;
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
        _reviews = const [];
        _loading = false;
      });
      return;
    }

    final service = ArchiveSynthesisService(
      store: ArchiveSynthesisStore(s.prefs),
      repository: appProviderContainer.read(archiveSynthesisRepositoryProvider),
      deviceIds: s.deviceIds,
    );
    final reviews = await service.loadMilestoneReviews(
      view: widget.view,
      entitlements: entitlements,
      userId: s.auth.currentSession?.userId,
    );
    if (!mounted) return;
    setState(() {
      _showUpgrade = false;
      _reviews = reviews;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.enableGpt5ArchiveSynthesis) {
      return const SizedBox.shrink();
    }
    if (_loading) return const SizedBox.shrink();

    if (_showUpgrade) {
      return ArchiveIntelligenceUpgradeCard(view: widget.view);
    }

    if (_reviews.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ArchiveSynthesisCopy.milestoneSectionTitle,
            style: VoiceMemoryTypography.sectionTitleStyle(),
          ),
          const SizedBox(height: 12),
          ..._reviews.map(_milestoneCard),
        ],
      ),
    );
  }

  Widget _milestoneCard(ArchiveMilestoneReview review) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            review.headline,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            review.narrative,
            style: const TextStyle(fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 8),
          if (review.primaryTheorySummary != null) ...[
            Text(
              review.primaryTheorySummary!.statement,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${review.primaryTheorySummary!.confidencePercent}% · '
              '${ArchiveSynthesisCopy.uncertaintyPrefix}${review.uncertaintyNote}',
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ] else ...[
            Text(
              '${ArchiveSynthesisCopy.uncertaintyPrefix}${review.uncertaintyNote}',
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}