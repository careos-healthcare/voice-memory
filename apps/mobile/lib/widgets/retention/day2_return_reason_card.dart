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

/// Day 2 return reason — one entry, user returned the next day. No fake
/// comparison; real insight cards take precedence when they exist.
class Day2ReturnReasonCard extends StatelessWidget {
  const Day2ReturnReasonCard({
    required this.onRecord, super.key,
    this.onDismiss,
    this.source = 'record',
    this.memoryOff = false,
  });

  final VoidCallback onRecord;
  final VoidCallback? onDismiss;
  final String source;
  final bool memoryOff;

  String get _body => memoryOff
      ? RepeatRecordingNudgeCopy.day2BodyMemoryOff
      : RepeatRecordingNudgeCopy.day2Body;

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.day2ReturnReasonSeen,
      entryCount: 1,
      source: source,
      stage: RepeatRecordingNudgeStage.day2Return,
      memoryScope: MemoryScopePolicy.scope.id,
      oncePerSession: true,
    );
    RepeatRecordingNudgeSession.markDay2Shown();

    return Container(
      key: const Key('day2_return_reason_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFEEF4FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  RepeatRecordingNudgeCopy.day2Title,
                  style: ArchiveMobileTypography.responsiveSectionTitle(
                    context,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  key: const Key('day2_return_reason_dismiss'),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Dismiss',
                  onPressed: () {
                    RepeatRecordingNudgeSession.dismissDay2();
                    onDismiss!();
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _body,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const Key('day2_return_reason_cta'),
            onPressed: () {
              ActivationFunnelAnalytics.track(
                ActivationFunnelAnalytics.day2ReturnReasonTapped,
                entryCount: 1,
                source: source,
                stage: RepeatRecordingNudgeStage.day2Return,
                memoryScope: MemoryScopePolicy.scope.id,
              );
              onRecord();
            },
            icon: const Icon(Icons.mic_none_outlined),
            label: const Text(RepeatRecordingNudgeCopy.day2Cta),
          ),
        ],
      ),
    );
  }
}