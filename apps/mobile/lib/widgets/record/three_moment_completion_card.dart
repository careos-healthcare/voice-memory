import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/three_moment_completion/three_moment_completion_analytics.dart';
import 'package:archiveme_mobile/features/three_moment_completion/three_moment_completion_model.dart';
import 'package:archiveme_mobile/features/three_moment_completion/three_moment_completion_store.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Unified early guidance for saves 1–3 — typed capture only, no fake entries.
class ThreeMomentCompletionCard extends StatefulWidget {
  const ThreeMomentCompletionCard({
    required this.result, required this.onPrimaryCta, super.key,
    this.store,
  });

  const ThreeMomentCompletionCard.test({
    required this.result, required this.onPrimaryCta, super.key,
    this.store,
  });

  final ThreeMomentCompletionResult result;
  final VoidCallback onPrimaryCta;
  final ThreeMomentCompletionStore? store;

  @override
  State<ThreeMomentCompletionCard> createState() =>
      _ThreeMomentCompletionCardState();
}

class _ThreeMomentCompletionCardState extends State<ThreeMomentCompletionCard> {
  var _trackedSeen = false;
  var _dismissedToday = false;

  ThreeMomentCompletionStore? get _store =>
      widget.store ?? ThreeMomentCompletionStore.instance();

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    ThreeMomentCompletionAnalytics.seen(result: widget.result);
  }

  void _handlePrimaryCta() {
    ThreeMomentCompletionAnalytics.ctaTapped(
      result: widget.result,
      actionType: widget.result.primaryActionType,
    );
    widget.onPrimaryCta();
  }

  Future<void> _handleNotToday() async {
    ThreeMomentCompletionAnalytics.ctaTapped(
      result: widget.result,
      actionType: ThreeMomentCompletionActionType.notToday,
    );
    ThreeMomentCompletionAnalytics.dismissedToday(result: widget.result);
    await _store?.dismissForDay();
    if (!mounted) return;
    setState(() => _dismissedToday = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissedToday) return const SizedBox.shrink();
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: const Key('three_moment_completion_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('three_moment_completion_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('three_moment_completion_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.noPressureLine,
            key: const Key('three_moment_completion_no_pressure'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: FilledButton(
              key: const Key('three_moment_completion_primary_cta'),
              onPressed: _handlePrimaryCta,
              child: Text(widget.result.primaryCta),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            key: const Key('three_moment_completion_not_today'),
            onPressed: () => unawaited(_handleNotToday()),
            child: Text(widget.result.secondaryCta),
          ),
        ],
      ),
    );
  }
}