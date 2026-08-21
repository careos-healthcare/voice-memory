import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/retention/repeat_recording_nudge_state.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/material.dart';

/// Compact, always-available record-again affordance after the first save.
class TinyRecordAgainCta extends StatelessWidget {
  const TinyRecordAgainCta({
    required this.entryCount, required this.onRecord, super.key,
    this.source = 'archive',
  });

  final int entryCount;
  final VoidCallback onRecord;
  final String source;

  @override
  Widget build(BuildContext context) {
    if (!RepeatRecordingNudgeGates.showRecordAgainCta(entryCount: entryCount)) {
      return const SizedBox.shrink();
    }

    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.recordAgainCtaSeen,
      entryCount: entryCount,
      source: source,
      stage: RepeatRecordingNudgeStage.recordAgain,
      memoryScope: MemoryScopePolicy.scope.id,
      oncePerSession: true,
    );

    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        key: Key('record_again_cta_$source'),
        onPressed: () {
          ActivationFunnelAnalytics.track(
            ActivationFunnelAnalytics.recordAgainCtaTapped,
            entryCount: entryCount,
            source: source,
            stage: RepeatRecordingNudgeStage.recordAgain,
            memoryScope: MemoryScopePolicy.scope.id,
          );
          onRecord();
        },
        icon: const Icon(Icons.mic_none_outlined, size: 18),
        label: const Text(RepeatRecordingNudgeCopy.recordAgainCta),
      ),
    );
  }
}