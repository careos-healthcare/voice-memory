import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/archive_state_object/archive_state_object.dart';
import '../features/retention/archive_discovery_service.dart';
import '../features/retention/retention_analytics.dart';
import '../services/app_services.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';

/// Proactive return trigger — gold highlight for new discoveries.
class ArchiveDiscoveryBanner extends StatelessWidget {
  const ArchiveDiscoveryBanner({
    super.key,
    required this.notice,
    this.onViewed,
  });

  final ArchiveDiscoveryNotice notice;
  final VoidCallback? onViewed;

  Future<void> _openDiscover(BuildContext context) async {
    RetentionAnalytics.discoveryBannerOpened();
    final entries = await AppServices.instance.journal.loadAll();
    final state = buildArchiveStateObjectV3(entries: entries);
    await ArchiveDiscoveryService(
      AppServices.instance.prefs,
    ).acknowledgeDiscovery(
      entries: entries,
      state: state,
      viewedAt: DateTime.now(),
    );
    onViewed?.call();
    if (context.mounted) context.go('/discover-yourself');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${notice.headline} ${notice.detail}',
      button: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VoiceMemoryColors.discoveryGoldBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: VoiceMemoryColors.discoveryGoldBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: VoiceMemoryColors.discoveryGold,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.headline,
                        style: VoiceMemoryTypography.cardTitleStyle(),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notice.detail,
                        style: VoiceMemoryTypography.bodyStyle(
                          color: VoiceMemoryColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => _openDiscover(context),
              style: TextButton.styleFrom(
                foregroundColor: VoiceMemoryColors.primaryIndigo,
                minimumSize: const Size(48, 48),
              ),
              child: const Text('See patterns'),
            ),
          ],
        ),
      ),
    );
  }
}
