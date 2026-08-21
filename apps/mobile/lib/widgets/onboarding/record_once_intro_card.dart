import 'dart:async' show unawaited;

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/onboarding/record_return_pro_state.dart';
import 'package:archiveme_mobile/features/onboarding/record_return_pro_store.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// A. Record once — zero-entry clarity near the record CTA.
/// One short line and one button; never blocks recording.
class RecordOnceIntroCard extends StatelessWidget {
  const RecordOnceIntroCard({required this.onRecord, super.key});

  final VoidCallback onRecord;

  static bool shouldShow(int entryCount) =>
      RecordReturnProGates.showRecordOnceIntro(entryCount: entryCount);

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.recordReturnLoopStarted,
      entryCount: 0,
      stage: RecordReturnProStage.recordOnce.id,
      source: 'record',
      oncePerSession: true,
    );
    unawaited(RecordReturnProStore.instance().markLoopStartedLogged());
    return Container(
      key: const Key('record_once_intro_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF6F4FF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            RecordReturnProCopy.recordOnceSupporting,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const Key('record_once_cta'),
            onPressed: () {
              ActivationFunnelAnalytics.track(
                ActivationFunnelAnalytics.recordOnceCtaTapped,
                entryCount: 0,
                stage: RecordReturnProStage.recordOnce.id,
                source: 'record',
              );
              onRecord();
            },
            icon: const Icon(Icons.mic_none_outlined),
            label: const Text(RecordReturnProCopy.recordOnceCta),
          ),
        ],
      ),
    );
  }
}