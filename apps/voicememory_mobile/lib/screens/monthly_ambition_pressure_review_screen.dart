import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../billing/revenuecat_service.dart';
import '../design/archive_mobile_spacing.dart';
import '../design/archive_mobile_typography.dart';
import '../design/archive_responsive_layout.dart';
import '../features/prove_enough/monthly_ambition_pressure_review_coordinator.dart';
import '../features/prove_enough/monthly_ambition_pressure_review_model.dart';
import '../features/retention/retention_metrics_tracker.dart';
import '../models/entitlement.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';
import '../widgets/prove_enough/monthly_ambition_pressure_review_card.dart';
import '../widgets/prove_enough/prove_enough_pattern_report_export_button.dart';

/// Full monthly prove_enough review — Pro after first free view.
class MonthlyAmbitionPressureReviewScreen extends StatefulWidget {
  const MonthlyAmbitionPressureReviewScreen({
    super.key,
    this.initialReview,
    this.initialEntitlements,
    this.canViewFull = true,
    this.onSeePro,
  });

  @visibleForTesting
  final MonthlyAmbitionPressureReview? initialReview;

  @visibleForTesting
  final PremiumEntitlements? initialEntitlements;

  @visibleForTesting
  final bool canViewFull;

  @visibleForTesting
  final VoidCallback? onSeePro;

  @override
  State<MonthlyAmbitionPressureReviewScreen> createState() =>
      _MonthlyAmbitionPressureReviewScreenState();
}

class _MonthlyAmbitionPressureReviewScreenState
    extends State<MonthlyAmbitionPressureReviewScreen> {
  MonthlyAmbitionPressureReview? _review;
  bool _canViewFull = true;
  bool _isPro = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialReview != null) {
      _review = widget.initialReview;
      _canViewFull = widget.canViewFull;
      _isPro = widget.initialEntitlements?.isPro == true;
      _loading = false;
      unawaited(_trackOpened());
      return;
    }
    _load();
  }

  Future<void> _load() async {
    final review = await MonthlyAmbitionPressureReviewCoordinator.load();
    PremiumEntitlements? entitlements = widget.initialEntitlements;
    if (AppServices.isInitialized) {
      entitlements = await AppServices.instance.billing.loadEntitlements();
    }
    final canViewFull =
        await MonthlyAmbitionPressureReviewCoordinator.canViewFullReview(
      entitlements,
    );
    if (canViewFull && entitlements?.isPro != true) {
      await MonthlyAmbitionPressureReviewCoordinator.consumeFreeReviewIfNeeded(
        entitlements,
      );
    }
    if (!mounted) return;
    setState(() {
      _review = review;
      _canViewFull = canViewFull;
      _isPro = entitlements?.isPro == true;
      _loading = false;
    });
    unawaited(_trackOpened());
    if (canViewFull) {
      unawaited(
        RetentionMetricsTracker.track(
          RetentionMetricsTracker.loopDirectionShown,
        ),
      );
    } else {
      unawaited(
        RetentionMetricsTracker.track(
          RetentionMetricsTracker.monthlyReviewPreviewShown,
        ),
      );
    }
  }

  Future<void> _trackOpened() async {
    await RetentionMetricsTracker.track(
      RetentionMetricsTracker.monthlyReviewOpened,
    );
  }

  bool get _billingReady =>
      widget.onSeePro != null || RevenueCatService.instance.isConfigured;

  void _openPro() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.monthlyReviewPaywallTapped,
      ),
    );
    if (widget.onSeePro != null) {
      widget.onSeePro!();
      return;
    }
    if (RevenueCatService.instance.isConfigured) {
      context.push('/subscription');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final review = _review!;
    if (!_canViewFull) {
      return ListView(
        padding: ArchiveMobileSpacing.pagePadding,
        children: [
          Text(
            MonthlyAmbitionPressureReview.screenTitle,
            style: ArchiveMobileTypography.archiveSurfaceTitle(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          MonthlyAmbitionPressureReviewCard(
            review: review,
            canViewFull: false,
            onSeePro: _billingReady ? _openPro : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          ProveEnoughPatternReportExportButton(
            isPro: _isPro,
            onSeePro: _billingReady ? _openPro : null,
          ),
        ],
      );
    }

    return ListView(
      padding: ArchiveMobileSpacing.pagePadding,
      children: [
        Text(
          MonthlyAmbitionPressureReview.screenTitle,
          style: ArchiveMobileTypography.archiveSurfaceTitle(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          review.monthLabel,
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.lg),
        _section(context, MonthlyAmbitionPressureReview.whatRepeatedTitle, review.whatRepeated),
        _section(context, MonthlyAmbitionPressureReview.whatCostTitle, review.whatSeemedToCostYou),
        _section(context, MonthlyAmbitionPressureReview.choiceVsPressureTitle, review.choiceVsPressureSummary),
        _section(context, MonthlyAmbitionPressureReview.restGuiltTitle, review.restGuiltSummary),
        _section(context, MonthlyAmbitionPressureReview.triggerMapTitle, review.triggerMapSummary),
        _directionSection(context, review),
        _section(context, MonthlyAmbitionPressureReview.nextMissionTitle, review.nextMonthMission),
        const SizedBox(height: AppSpacing.lg),
        ProveEnoughPatternReportExportButton(
          isPro: _isPro,
          onSeePro: _billingReady ? _openPro : null,
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: ArchiveResponsiveLayout.cardInsets(context),
        decoration: VoiceMemoryCards.standard(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: ArchiveMobileTypography.cardLabel(context)),
            const SizedBox(height: AppSpacing.xs),
            Text(body, style: ArchiveMobileTypography.explanationBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _directionSection(
    BuildContext context,
    MonthlyAmbitionPressureReview review,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: ArchiveResponsiveLayout.cardInsets(context),
        decoration: VoiceMemoryCards.standard(
          background: const Color(0xFFF8FBFF),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              MonthlyAmbitionPressureReview.directionTitle,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              review.direction.copy,
              style: ArchiveMobileTypography.explanationBody(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (review.whatChanged.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                review.whatChanged,
                style: ArchiveMobileTypography.body(context).copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (review.directionEvidence.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              ...review.directionEvidence.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    '· $line',
                    style: ArchiveMobileTypography.body(context),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
