import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pro_lock_moment/pro_lock_moment_analytics.dart';
import '../../features/pro_lock_moment/pro_lock_moment_engine.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import 'pro_lock_moment_sheet.dart';

/// Restrained Pro lock moment after first proof — opens detail sheet.
class ProLockMomentCard extends StatefulWidget {
  const ProLockMomentCard({
    super.key,
    required this.entryCount,
    required this.hasFirstProof,
    required this.hasConfirmedRepeat,
    required this.onSeePro,
    required this.onDismiss,
    this.source = ProLockMomentEngine.recordPostSaveSource,
  });

  final int entryCount;
  final bool hasFirstProof;
  final bool hasConfirmedRepeat;
  final VoidCallback onSeePro;
  final VoidCallback onDismiss;
  final String source;

  @override
  State<ProLockMomentCard> createState() => _ProLockMomentCardState();
}

class _ProLockMomentCardState extends State<ProLockMomentCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    ProLockMomentAnalytics.seen(
      source: widget.source,
      entryCount: widget.entryCount,
      hasFirstProof: widget.hasFirstProof,
      hasConfirmedRepeat: widget.hasConfirmedRepeat,
    );
  }

  Future<void> _openSheet() async {
    ProLockMomentAnalytics.ctaTapped(
      source: widget.source,
      entryCount: widget.entryCount,
      hasFirstProof: widget.hasFirstProof,
      hasConfirmedRepeat: widget.hasConfirmedRepeat,
      actionType: 'open_sheet',
    );
    await ProLockMomentSheet.show(
      context,
      source: widget.source,
      entryCount: widget.entryCount,
      hasFirstProof: widget.hasFirstProof,
      hasConfirmedRepeat: widget.hasConfirmedRepeat,
      onSeePro: widget.onSeePro,
    );
  }

  void _handleDismiss() {
    ProLockMomentAnalytics.dismissed(
      source: widget.source,
      entryCount: widget.entryCount,
      hasFirstProof: widget.hasFirstProof,
      hasConfirmedRepeat: widget.hasConfirmedRepeat,
    );
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();
    final display = ProLockMomentEngine.buildDisplay();
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );

    return Container(
      key: const Key('pro_lock_moment_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            display.title,
            key: const Key('pro_lock_moment_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            display.body,
            key: const Key('pro_lock_moment_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            display.paidReason,
            key: const Key('pro_lock_moment_paid_reason'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('pro_lock_moment_dismiss'),
                  onPressed: _handleDismiss,
                  child: Text(display.secondary),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton(
                  key: const Key('pro_lock_moment_cta'),
                  onPressed: _openSheet,
                  child: Text(display.cta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
