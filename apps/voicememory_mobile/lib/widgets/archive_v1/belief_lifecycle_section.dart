import 'package:flutter/material.dart';

import '../../design/user_facing_date.dart';
import '../../features/belief_lifecycle/belief_lifecycle_copy.dart';
import '../../features/belief_lifecycle/belief_lifecycle_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/voicememory_colors.dart';
import '../../features/archive_discovery_share/archive_discovery_share_moments.dart';
import '../../theme/voicememory_typography.dart';
import '../archive_discovery_share/share_discovery_button.dart';

/// Belief lifecycle — first/last seen, status, retired beliefs.
class BeliefLifecycleSection extends StatelessWidget {
  const BeliefLifecycleSection({
    super.key,
    required this.lifecycle,
  });

  final BeliefLifecycleView lifecycle;

  @override
  Widget build(BuildContext context) {
    if (!lifecycle.hasContent) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          BeliefLifecycleCopy.sectionTitle,
          style: VoiceMemoryTypography.sectionLabelStyle(
            accent: VoiceMemoryColors.primaryIndigo,
          ),
        ),
        const SizedBox(height: 12),
        if (lifecycle.current != null) ...[
          _LifecycleCard(entry: lifecycle.current!, isCurrent: true),
        ],
        for (final retired in lifecycle.retired) ...[
          const SizedBox(height: 12),
          _LifecycleCard(entry: retired, isCurrent: false),
        ],
      ],
    );
  }
}

class _LifecycleCard extends StatelessWidget {
  const _LifecycleCard({
    required this.entry,
    required this.isCurrent,
  });

  final BeliefLifecycleEntry entry;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final isDead = entry.isNoLongerDetected;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDead
            ? VoiceMemoryColors.surfaceSecondary.withValues(alpha: 0.6)
            : VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDead
              ? VoiceMemoryColors.border.withValues(alpha: 0.8)
              : VoiceMemoryColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDead) ...[
            Text(
              BeliefLifecycleCopy.noLongerDetectedTitle,
              style: VoiceMemoryTypography.sectionLabelStyle(
                accent: AppTheme.muted,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            '"${entry.statement}"',
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: AppTheme.foreground,
            ),
          ),
          const SizedBox(height: 12),
          if (isDead) ...[
            _row(
              BeliefLifecycleCopy.lastDetectedLabel,
              _formatDate(entry.lastSeen),
            ),
          ] else ...[
            _row(
              BeliefLifecycleCopy.firstSeenLabel,
              _formatDate(entry.firstSeen),
            ),
            _row(
              BeliefLifecycleCopy.lastSeenLabel,
              _formatDate(entry.lastSeen),
            ),
            _row(
              BeliefLifecycleCopy.statusLabel,
              BeliefLifecycleCopy.statusLabelFor(entry.status),
            ),
          ],
          if (ArchiveDiscoveryShareMoments.fromLifecycleEntry(entry)
              case final shareCard?) ...[
            const SizedBox(height: 8),
            ShareDiscoveryButton(
              card: shareCard,
              surface: 'archive_belief_lifecycle',
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label:\n$value',
        style: const TextStyle(
          color: AppTheme.muted,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  String _formatDate(DateTime? at) {
    if (at == null) return '—';
    return formatUserFacingDate(at);
  }
}
