import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_store.dart';
import 'package:archiveme_mobile/features/quiet_signal/quiet_signal_analytics.dart';
import 'package:archiveme_mobile/features/quiet_signal/quiet_signal_copy.dart';
import 'package:archiveme_mobile/features/quiet_signal/quiet_signal_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Quiet / not-seen-recently card on Patterns and related surfaces.
class QuietSignalCard extends StatefulWidget {
  const QuietSignalCard({
    required this.signal, required this.entryCount, required this.source, super.key,
    this.store,
    this.skipPersist = false,
    this.onKeepWatching,
    this.onViewPatternDetails,
    this.showViewPatternDetails = false,
    this.compact = false,
  });

  const QuietSignalCard.test({
    required this.signal, required this.entryCount, required this.source, super.key,
    this.store,
    this.onKeepWatching,
    this.onViewPatternDetails,
    this.showViewPatternDetails = false,
    this.compact = false,
  }) : skipPersist = true;

  final QuietSignal signal;
  final int entryCount;
  final String source;
  final ComeBackTomorrowV2Store? store;
  final bool skipPersist;
  final VoidCallback? onKeepWatching;
  final VoidCallback? onViewPatternDetails;
  final bool showViewPatternDetails;
  final bool compact;

  @override
  State<QuietSignalCard> createState() => _QuietSignalCardState();
}

class _QuietSignalCardState extends State<QuietSignalCard> {
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
        store.recordQuietDetection(
          lastSeenDateKey: widget.signal.lastSeenDateKey,
        ),
      );
    }
    QuietSignalAnalytics.seen(
      source: widget.source,
      entryCount: widget.entryCount,
      daysSinceSeen: widget.signal.daysSinceSeen,
    );
  }

  Future<void> _onKeepWatching() async {
    QuietSignalAnalytics.ctaTapped(
      source: widget.source,
      entryCount: widget.entryCount,
      actionType: 'keep_watching',
    );
    if (!widget.skipPersist || widget.store != null) {
      final store = widget.store ?? ComeBackTomorrowV2Store.instance();
      await store.dismissQuietSignal();
    }
    widget.onKeepWatching?.call();
  }

  void _onViewPatternDetails() {
    QuietSignalAnalytics.ctaTapped(
      source: widget.source,
      entryCount: widget.entryCount,
      actionType: 'view_pattern_details',
    );
    widget.onViewPatternDetails?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: widget.compact ? 1.4 : 1.45,
    );

    return Container(
      key: const Key('quiet_signal_card'),
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF7F8FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.signal.title,
            key: const Key('quiet_signal_card_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          SizedBox(height: widget.compact ? AppSpacing.xs / 2 : AppSpacing.xs),
          Text(
            widget.signal.body,
            key: const Key('quiet_signal_card_body'),
            style: bodyStyle,
          ),
          SizedBox(height: widget.compact ? AppSpacing.xs / 2 : AppSpacing.xs),
          Text(
            widget.signal.footer,
            key: const Key('quiet_signal_card_footer'),
            style: bodyStyle,
          ),
          SizedBox(height: widget.compact ? AppSpacing.xs : AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              TextButton(
                key: const Key('quiet_signal_card_cta_keep_watching'),
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
                  style: ArchiveMobileTypography.responsiveHelper(context)
                      .copyWith(
                        color: AppColors.accentPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                ),
              ),
              if (widget.showViewPatternDetails &&
                  widget.onViewPatternDetails != null)
                TextButton(
                  key: const Key('quiet_signal_card_cta_view_details'),
                  onPressed: _onViewPatternDetails,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentPrimary,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    QuietSignalCopy.ctaViewPatternDetails,
                    style: ArchiveMobileTypography.responsiveHelper(context)
                        .copyWith(
                          color: AppColors.accentPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}