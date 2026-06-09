import 'package:flutter/material.dart';

import '../../features/archive_discovery_share/archive_discovery_share_analytics.dart';
import '../../features/first25/first25_user_metrics.dart';
import '../../features/archive_discovery_share/archive_discovery_share_card_model.dart';
import '../../features/archive_discovery_share/archive_discovery_share_copy.dart';
import '../../features/archive_discovery_share/archive_discovery_share_palette.dart';
import '../../theme/app_theme.dart';
import 'archive_discovery_share_card.dart';

/// Bottom sheet preview + share for an in-context archive discovery.
Future<void> showArchiveDiscoveryShareSheet(
  BuildContext context, {
  required ArchiveDiscoveryShareCardModel card,
  required String surface,
}) {
  First25UserMetrics.trackShareCardOpened(
    surface: surface,
    cardType: card.type.analyticsValue,
  );
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _ArchiveDiscoveryShareSheetBody(
      card: card,
      surface: surface,
    ),
  );
}

class _ArchiveDiscoveryShareSheetBody extends StatefulWidget {
  const _ArchiveDiscoveryShareSheetBody({
    required this.card,
    required this.surface,
  });

  final ArchiveDiscoveryShareCardModel card;
  final String surface;

  @override
  State<_ArchiveDiscoveryShareSheetBody> createState() =>
      _ArchiveDiscoveryShareSheetBodyState();
}

class _ArchiveDiscoveryShareSheetBodyState
    extends State<_ArchiveDiscoveryShareSheetBody> {
  final _exportKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await ArchiveDiscoveryShareCard.sharePngViaSheet(
        boundaryKey: _exportKey,
        card: widget.card,
        surface: widget.surface,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share: $e')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ArchiveDiscoverySharePalette.fromContext(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ArchiveDiscoveryShareCopy.sheetTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'A screenshot-safe card — short insight only, no full transcripts.',
            style: TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          Center(
            child: ArchiveDiscoveryShareCard(
              card: widget.card,
              exportKey: _exportKey,
              palette: palette,
              fixedWidth: ArchiveDiscoveryShareCopy.exportWidth,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _sharing ? null : _share,
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share, size: 18),
            label: Text(
              _sharing
                  ? 'Preparing…'
                  : ArchiveDiscoveryShareCopy.shareDiscoveryLabel,
            ),
          ),
        ],
      ),
    );
  }
}
