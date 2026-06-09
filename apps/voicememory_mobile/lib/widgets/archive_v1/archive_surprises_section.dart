import 'package:flutter/material.dart';

import '../../features/archive_surprises/archive_surprises_copy.dart';
import '../../features/archive_surprises/archive_surprises_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/voicememory_colors.dart';
import '../../features/archive_discovery_share/archive_discovery_share_moments.dart';
import '../../theme/voicememory_typography.dart';
import '../archive_discovery_share/share_discovery_button.dart';

/// Evidence-backed observations vs apparent self-image.
class ArchiveSurprisesSection extends StatelessWidget {
  const ArchiveSurprisesSection({
    super.key,
    required this.surprises,
  });

  final ArchiveSurprisesView surprises;

  @override
  Widget build(BuildContext context) {
    if (surprises.emptyMessage != null && !surprises.hasObservations) {
      return _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title(),
            const SizedBox(height: 8),
            Text(
              surprises.emptyMessage!,
              style: const TextStyle(color: AppTheme.muted, height: 1.45),
            ),
          ],
        ),
      );
    }

    if (!surprises.hasObservations) return const SizedBox.shrink();

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(),
          const SizedBox(height: 12),
          for (final row in surprises.observations) ...[
            _observationTile(row),
            if (row != surprises.observations.last)
              const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _title() {
    return Text(
      ArchiveSurprisesCopy.sectionTitle,
      style: VoiceMemoryTypography.sectionLabelStyle(
        accent: VoiceMemoryColors.primaryIndigo,
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: child,
    );
  }

  Widget _observationTile(ArchiveSurpriseObservation row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.observation,
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w500,
            color: AppTheme.foreground,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${ArchiveSurprisesCopy.evidenceLabel}: ${row.evidenceCount} '
          '${row.evidenceCount == 1 ? 'recording' : 'recordings'}',
          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
        ),
        if (ArchiveDiscoveryShareMoments.fromSurprise(row) case final shareCard?) ...[
          const SizedBox(height: 4),
          ShareDiscoveryButton(
            card: shareCard,
            surface: 'archive_surprise',
          ),
        ],
      ],
    );
  }
}
