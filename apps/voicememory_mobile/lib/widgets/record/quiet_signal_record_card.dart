import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/come_back_tomorrow/come_back_tomorrow_v2_store.dart';
import '../../features/quiet_signal/quiet_signal_analytics.dart';
import '../../features/quiet_signal/quiet_signal_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Quiet signal card on the Record ready surface.
class QuietSignalRecordCard extends StatefulWidget {
  const QuietSignalRecordCard({
    super.key,
    required this.signal,
    required this.entryCount,
    this.store,
    this.skipPersist = false,
    this.onKeepWatching,
  });

  const QuietSignalRecordCard.test({
    super.key,
    required this.signal,
    required this.entryCount,
    this.store,
    this.onKeepWatching,
  }) : skipPersist = true;

  final QuietSignal signal;
  final int entryCount;
  final ComeBackTomorrowV2Store? store;
  final bool skipPersist;
  final VoidCallback? onKeepWatching;

  @override
  State<QuietSignalRecordCard> createState() => _QuietSignalRecordCardState();
}

class _QuietSignalRecordCardState extends State<QuietSignalRecordCard> {
  bool _tracked = false;

  @override
  void initState() {
    super.initState();
    _trackSeen();
  }

  void _trackSeen() {
    if (_tracked) return;
    _tracked = true;
    if (!widget.skipPersist || widget.store != null) {
      final store = widget.store ?? ComeBackTomorrowV2Store.instance();
      unawaited(
        store.recordQuietDetection(lastSeenDateKey: widget.signal.lastSeenDateKey),
      );
    }
    QuietSignalAnalytics.seen(
      source: widget.signal.source,
      entryCount: widget.entryCount,
      daysSinceSeen: widget.signal.daysSinceSeen,
    );
  }

  Future<void> _onKeepWatching() async {
    QuietSignalAnalytics.ctaTapped(
      source: widget.signal.source,
      entryCount: widget.entryCount,
      actionType: 'keep_watching',
    );
    if (!widget.skipPersist || widget.store != null) {
      final store = widget.store ?? ComeBackTomorrowV2Store.instance();
      await store.dismissQuietSignal();
    }
    widget.onKeepWatching?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
    );

    return Container(
      key: const Key('quiet_signal_record_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF7F8FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.signal.title,
            key: const Key('quiet_signal_record_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.signal.body,
            key: const Key('quiet_signal_record_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.signal.footer,
            key: const Key('quiet_signal_record_footer'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('quiet_signal_record_cta'),
              onPressed: _onKeepWatching,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentPrimary,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                widget.signal.ctaKeepWatching,
                style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                  color: AppColors.accentPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
