import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_backup_bridge/archive_backup_bridge_analytics.dart';
import '../../features/archive_backup_bridge/archive_backup_bridge_engine.dart';
import '../../features/archive_backup_bridge/archive_backup_bridge_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import 'archive_backup_bridge_sheet.dart';

/// Preservation bridge when the archive has become meaningfully valuable.
class ArchiveBackupBridgeCard extends StatefulWidget {
  const ArchiveBackupBridgeCard({
    super.key,
    required this.contextData,
    this.onSeePro,
    required this.onDismiss,
    this.compact = false,
  });

  final ArchiveBackupBridgeContext contextData;
  final VoidCallback? onSeePro;
  final VoidCallback onDismiss;
  final bool compact;

  @override
  State<ArchiveBackupBridgeCard> createState() =>
      _ArchiveBackupBridgeCardState();
}

class _ArchiveBackupBridgeCardState extends State<ArchiveBackupBridgeCard> {
  var _trackedSeen = false;

  ArchiveBackupBridgeContext get _context => widget.contextData;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    ArchiveBackupBridgeAnalytics.seen(
      source: _context.surface.analyticsValue,
      entryCount: _context.entryCount,
      hasConfirmedRepeat: _context.hasConfirmedRepeat,
      hasReportPreview: _context.hasReportPreview,
    );
  }

  Future<void> _openSheet() async {
    ArchiveBackupBridgeAnalytics.ctaTapped(
      source: _context.surface.analyticsValue,
      entryCount: _context.entryCount,
      hasConfirmedRepeat: _context.hasConfirmedRepeat,
      hasReportPreview: _context.hasReportPreview,
      actionType: 'open_sheet',
    );
    await ArchiveBackupBridgeSheet.show(
      context,
      contextData: _context,
      onSeePro: widget.onSeePro,
    );
  }

  void _handleDismiss() {
    ArchiveBackupBridgeAnalytics.dismissed(
      source: _context.surface.analyticsValue,
      entryCount: _context.entryCount,
      hasConfirmedRepeat: _context.hasConfirmedRepeat,
      hasReportPreview: _context.hasReportPreview,
    );
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();
    final display = ArchiveBackupBridgeEngine.buildDisplay();
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);
    final showProCta = ArchiveBackupBridgeEngine.showProCta(_context);

    return Container(
      key: const Key('archive_backup_bridge_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            display.title,
            key: const Key('archive_backup_bridge_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            display.body,
            key: const Key('archive_backup_bridge_body'),
            style: bodyStyle,
          ),
          if (!widget.compact) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              display.deviceBackupToday,
              key: const Key('archive_backup_bridge_device_backup'),
              style: bodyStyle,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('archive_backup_bridge_dismiss'),
                  onPressed: _handleDismiss,
                  child: Text(display.secondary),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton(
                  key: const Key('archive_backup_bridge_cta'),
                  onPressed: _openSheet,
                  child: Text(display.cta),
                ),
              ),
            ],
          ),
          if (showProCta && widget.onSeePro != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('archive_backup_bridge_see_pro'),
                onPressed: widget.onSeePro,
                child: Text(display.sheetSeeProCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
