import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/loop_mode/loop_mode_coordinator.dart';
import '../../features/prove_enough/monthly_ambition_pressure_review_coordinator.dart';
import '../../features/prove_enough/monthly_ambition_pressure_review_model.dart';
import '../../features/retention/retention_metrics_tracker.dart';
import '../../models/entitlement.dart';
import '../../services/app_services.dart';
import '../../theme/app_spacing.dart';
import 'monthly_ambition_pressure_review_card.dart';

/// Loads and shows the monthly prove_enough review card on loop surfaces.
class MonthlyAmbitionPressureReviewSection extends StatefulWidget {
  const MonthlyAmbitionPressureReviewSection({super.key});

  @override
  State<MonthlyAmbitionPressureReviewSection> createState() =>
      _MonthlyAmbitionPressureReviewSectionState();
}

class _MonthlyAmbitionPressureReviewSectionState
    extends State<MonthlyAmbitionPressureReviewSection> {
  MonthlyAmbitionPressureReview? _review;
  bool _canViewFull = true;
  bool _loading = true;
  var _previewTracked = false;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    final loop = AppServices.isInitialized
        ? await LoopModeCoordinator.loadActive()
        : null;
    if (loop?.isProveEnough != true) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    final review = await MonthlyAmbitionPressureReviewCoordinator.load();
    PremiumEntitlements? entitlements;
    if (AppServices.isInitialized) {
      entitlements = await AppServices.instance.billing.loadEntitlements();
    }
    final canViewFull =
        await MonthlyAmbitionPressureReviewCoordinator.canViewFullReview(
      entitlements,
    );

    if (!mounted) return;
    setState(() {
      _review = review;
      _canViewFull = canViewFull;
      _loading = false;
    });

    if (!canViewFull) {
      unawaited(_trackPreviewShown());
    }
  }

  Future<void> _trackPreviewShown() async {
    if (_previewTracked) return;
    _previewTracked = true;
    await RetentionMetricsTracker.track(
      RetentionMetricsTracker.monthlyReviewPreviewShown,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _review == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MonthlyAmbitionPressureReviewCard(
          review: _review!,
          canViewFull: _canViewFull,
          onSeePro: () {
            unawaited(
              RetentionMetricsTracker.track(
                RetentionMetricsTracker.monthlyReviewPaywallTapped,
              ),
            );
            context.push('/subscription');
          },
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
