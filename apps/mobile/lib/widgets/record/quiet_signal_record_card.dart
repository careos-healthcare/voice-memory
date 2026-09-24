import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_store.dart';
import 'package:archiveme_mobile/features/quiet_signal/quiet_signal_analytics.dart';
import 'package:archiveme_mobile/features/quiet_signal/quiet_signal_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/cues/emotional_cues.dart';
import 'package:flutter/material.dart';

/// Quiet signal card on the Record ready surface.
class QuietSignalRecordCard extends StatefulWidget {
  const QuietSignalRecordCard({
    required this.signal,
    required this.entryCount,
    super.key,
    this.store,
    this.skipPersist = false,
    this.onKeepWatching,
  });

  const QuietSignalRecordCard.test({
    required this.signal,
    required this.entryCount,
    super.key,
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
        store.recordQuietDetection(
          lastSeenDateKey: widget.signal.lastSeenDateKey,
        ),
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
    return Padding(
      key: const Key('quiet_signal_record_card'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HesitationSignalCue(
            labelKey: const Key('quiet_signal_record_title'),
            lineKey: const Key('quiet_signal_record_body'),
            noteKey: const Key('quiet_signal_record_footer'),
            label: widget.signal.title,
            line: widget.signal.body,
            note: widget.signal.footer,
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
                style: ArchiveMobileTypography.responsiveHelper(context)
                    .copyWith(
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
