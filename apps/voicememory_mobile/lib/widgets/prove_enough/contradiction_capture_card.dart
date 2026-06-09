import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/prove_enough/prove_enough_contradiction_model.dart';
import '../../features/prove_enough/prove_enough_contradiction_store.dart';
import '../../features/retention/retention_metrics_tracker.dart';
import '../../services/app_services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Lets the user capture evidence that challenges the proving-enough loop.
class ContradictionCaptureCard extends StatefulWidget {
  const ContradictionCaptureCard({
    super.key,
    this.journeyId,
    this.entryId,
    this.onSaved,
  });

  final String? journeyId;
  final String? entryId;
  final VoidCallback? onSaved;

  @override
  State<ContradictionCaptureCard> createState() =>
      _ContradictionCaptureCardState();
}

class _ContradictionCaptureCardState extends State<ContradictionCaptureCard> {
  static const _savedCopy = 'This challenges the proving-enough loop.';

  String? _savedLabel;
  bool _busy = false;
  var _metricsTracked = false;

  @override
  void initState() {
    super.initState();
    unawaited(_trackShown());
  }

  Future<void> _trackShown() async {
    if (_metricsTracked) return;
    _metricsTracked = true;
    if (!AppServices.isInitialized) return;
    await RetentionMetricsTracker.track(
      RetentionMetricsTracker.contradictionCaptureShown,
    );
  }

  Future<void> _save(ProveEnoughContradictionOption option) async {
    if (_busy) return;
    setState(() => _busy = true);
    if (AppServices.isInitialized) {
      await ProveEnoughContradictionStore.instance().save(
        option: option,
        journeyId: widget.journeyId,
        entryId: widget.entryId,
      );
      await RetentionMetricsTracker.track(
        RetentionMetricsTracker.contradictionSaved,
      );
    }
    if (!mounted) return;
    setState(() {
      _savedLabel = option.label;
      _busy = false;
    });
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('contradiction_capture_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFDF8F3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Did this challenge the loop?',
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'ArchiveMe should track evidence that proves the loop wrong too.',
            style: ArchiveMobileTypography.body(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (_savedLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _savedCopy,
              style: ArchiveMobileTypography.body(context).copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _savedLabel!,
              style: ArchiveMobileTypography.body(context).copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            ...ProveEnoughContradictionOption.values.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: OutlinedButton(
                  key: Key('contradiction_option_${option.id}'),
                  onPressed: _busy ? null : () => _save(option),
                  child: Text(option.label),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
