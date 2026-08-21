import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/prove_enough/next_evidence_mission_model.dart';
import 'package:archiveme_mobile/features/retention/retention_metrics_tracker.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One precise next recording mission for prove_enough retention.
class NextEvidenceMissionCard extends StatelessWidget {
  const NextEvidenceMissionCard({
    required this.mission, super.key,
    this.onRecordTapped,
  });

  final NextEvidenceMissionModel mission;
  final VoidCallback? onRecordTapped;

  void _record(BuildContext context) {
    onRecordTapped?.call();
    if (AppServices.isInitialized) {
      unawaited(
        RetentionMetricsTracker.track(
          RetentionMetricsTracker.nextEvidenceMissionTapped,
        ),
      );
    }
    context.go(
      '/record?prompt=${Uri.encodeComponent(mission.mission)}&autostart=1',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('next_evidence_mission_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FBFF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Next evidence mission',
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(mission.mission, style: ArchiveMobileTypography.body(context)),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('next_evidence_mission_record_cta'),
            onPressed: () => _record(context),
            child: const Text('Record this when it happens'),
          ),
        ],
      ),
    );
  }
}