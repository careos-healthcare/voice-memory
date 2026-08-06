import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/come_back_tomorrow/come_back_tomorrow_v2_analytics.dart';
import '../../features/come_back_tomorrow/come_back_tomorrow_v2_model.dart';
import '../../features/come_back_tomorrow/come_back_tomorrow_v2_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Quiet signal when an active watch target has not appeared recently.
class ComeBackTomorrowQuietSignalCard extends StatefulWidget {
  const ComeBackTomorrowQuietSignalCard({
    super.key,
    required this.signal,
    required this.entryCount,
    this.store,
    this.skipPersist = false,
    this.onKeepWatching,
  });

  const ComeBackTomorrowQuietSignalCard.test({
    super.key,
    required this.signal,
    required this.entryCount,
    this.store,
    this.onKeepWatching,
  }) : skipPersist = true;

  final ComeBackTomorrowQuietSignal signal;
  final int entryCount;
  final ComeBackTomorrowV2Store? store;
  final bool skipPersist;
  final VoidCallback? onKeepWatching;

  @override
  State<ComeBackTomorrowQuietSignalCard> createState() =>
      _ComeBackTomorrowQuietSignalCardState();
}

class _ComeBackTomorrowQuietSignalCardState
    extends State<ComeBackTomorrowQuietSignalCard> {
  bool _tracked = false;

  @override
  void initState() {
    super.initState();
    _trackSeen();
  }

  void _trackSeen() {
    if (_tracked) return;
    _tracked = true;
    ComeBackTomorrowV2Analytics.quietSignalSeen(
      source: widget.signal.source,
      entryCount: widget.entryCount,
      daysSinceSet: widget.signal.daysSinceSet,
    );
  }

  Future<void> _onKeepWatching() async {
    if (!widget.skipPersist || widget.store != null) {
      final store = widget.store ?? ComeBackTomorrowV2Store.instance();
      await store.dismissQuietSignal();
    }
    widget.onKeepWatching?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary);

    return Container(
      key: const Key('come_back_tomorrow_quiet_signal_card'),
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
            key: const Key('come_back_tomorrow_quiet_signal_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.signal.body,
            key: const Key('come_back_tomorrow_quiet_signal_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.signal.footer,
            key: const Key('come_back_tomorrow_quiet_signal_footer'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('come_back_tomorrow_quiet_signal_cta'),
              onPressed: _onKeepWatching,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentPrimary,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                widget.signal.cta,
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
