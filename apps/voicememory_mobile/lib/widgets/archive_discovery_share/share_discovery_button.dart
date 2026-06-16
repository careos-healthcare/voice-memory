import 'package:flutter/material.dart';

import '../../features/archive_discovery_share/archive_discovery_share_analytics.dart';
import '../../features/archive_discovery_share/archive_discovery_share_card_model.dart';
import '../../features/archive_discovery_share/archive_discovery_share_copy.dart';
import '../../theme/voicememory_colors.dart';
import 'share_discovery_sheet.dart';

/// In-context "Share Discovery" affordance on archive insight surfaces.
class ShareDiscoveryButton extends StatelessWidget {
  const ShareDiscoveryButton({
    super.key,
    required this.card,
    required this.surface,
  });

  final ArchiveDiscoveryShareCardModel card;
  final String surface;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: Key('share_discovery_$surface'),
        onPressed: () => _onPressed(context),
        icon: Icon(
          Icons.ios_share,
          size: 16,
          color: VoiceMemoryColors.primaryIndigo.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? 0.95 : 1,
          ),
        ),
        label: Text(
          ArchiveDiscoveryShareCopy.shareDiscoveryLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: VoiceMemoryColors.primaryIndigo.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark ? 0.95 : 1,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onPressed(BuildContext context) async {
    await ArchiveDiscoveryShareAnalytics.discoveryShareTapped(
      cardType: card.type,
      cardId: card.id,
      surface: surface,
    );
    if (!context.mounted) return;
    await showArchiveDiscoveryShareSheet(context, card: card, surface: surface);
  }
}
