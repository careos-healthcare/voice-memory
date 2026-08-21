import 'package:archiveme_mobile/features/archive_discovery_share/archive_discovery_share_analytics.dart';
import 'package:archiveme_mobile/features/archive_discovery_share/archive_discovery_share_card_model.dart';
import 'package:archiveme_mobile/features/archive_discovery_share/archive_discovery_share_copy.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/widgets/archive_discovery_share/share_discovery_sheet.dart';
import 'package:flutter/material.dart';

/// In-context "Share Discovery" affordance on archive insight surfaces.
class ShareDiscoveryButton extends StatelessWidget {
  const ShareDiscoveryButton({
    required this.card, required this.surface, super.key,
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