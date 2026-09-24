import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_analytics.dart';
import 'package:archiveme_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_model.dart';
import 'package:archiveme_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_store.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/cues/emotional_cues.dart';
import 'package:flutter/material.dart';

/// Quiet signal when an active watch target has not appeared recently.
class ComeBackTomorrowQuietSignalCard extends StatefulWidget {
  const ComeBackTomorrowQuietSignalCard({
    required this.signal, required this.entryCount, super.key,
    this.store,
    this.skipPersist = false,
    this.onKeepWatching,
  });

  const ComeBackTomorrowQuietSignalCard.test({
    required this.signal, required this.entryCount, super.key,
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
    return Padding(
      key: const Key('come_back_tomorrow_quiet_signal_card'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HesitationSignalCue(
            labelKey: const Key('come_back_tomorrow_quiet_signal_title'),
            lineKey: const Key('come_back_tomorrow_quiet_signal_body'),
            noteKey: const Key('come_back_tomorrow_quiet_signal_footer'),
            label: widget.signal.title,
            line: widget.signal.body,
            note: widget.signal.footer,
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