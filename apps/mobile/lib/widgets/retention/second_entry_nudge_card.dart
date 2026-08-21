import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/retention/repeat_recording_nudge_state.dart';
import 'package:archiveme_mobile/features/retention/repeat_recording_nudge_store.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Light nudge for users with exactly one entry — dismissible, once per session.
class SecondEntryNudgeCard extends StatelessWidget {
  const SecondEntryNudgeCard({
    required this.onRecord, required this.onDismiss, super.key,
    this.source = 'record',
  });

  final VoidCallback onRecord;
  final VoidCallback onDismiss;
  final String source;

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.secondEntryNudgeSeen,
      entryCount: 1,
      source: source,
      stage: RepeatRecordingNudgeStage.secondEntry,
      memoryScope: MemoryScopePolicy.scope.id,
      oncePerSession: true,
    );
    RepeatRecordingNudgeSession.markSecondEntryShown();

    return Container(
      key: const Key('second_entry_nudge_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF4F7FB),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  RepeatRecordingNudgeCopy.secondEntryTitle,
                  style: ArchiveMobileTypography.responsiveSectionTitle(
                    context,
                  ),
                ),
              ),
              IconButton(
                key: const Key('second_entry_nudge_dismiss'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Dismiss',
                onPressed: () {
                  ActivationFunnelAnalytics.track(
                    ActivationFunnelAnalytics.secondEntryNudgeDismissed,
                    entryCount: 1,
                    source: source,
                    stage: RepeatRecordingNudgeStage.secondEntry,
                    memoryScope: MemoryScopePolicy.scope.id,
                  );
                  RepeatRecordingNudgeSession.dismissSecondEntry();
                  onDismiss();
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            RepeatRecordingNudgeCopy.secondEntryBody,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const Key('second_entry_nudge_cta'),
            onPressed: () {
              ActivationFunnelAnalytics.track(
                ActivationFunnelAnalytics.secondEntryNudgeTapped,
                entryCount: 1,
                source: source,
                stage: RepeatRecordingNudgeStage.secondEntry,
                memoryScope: MemoryScopePolicy.scope.id,
              );
              onRecord();
            },
            icon: const Icon(Icons.mic_none_outlined),
            label: const Text(RepeatRecordingNudgeCopy.secondEntryCta),
          ),
        ],
      ),
    );
  }
}