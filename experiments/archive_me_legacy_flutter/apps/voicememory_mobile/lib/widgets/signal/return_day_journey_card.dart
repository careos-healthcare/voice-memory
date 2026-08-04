import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/retention/next_evidence_reminder_service.dart';
import '../../features/retention/retention_metrics_tracker.dart';
import '../../features/signal_journey/signal_journey_model.dart';
import '../../features/signal_journey/signal_journey_navigation.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Dominant Record tab card when user returns with an active signal journey.
class ReturnDayJourneyCard extends StatefulWidget {
  const ReturnDayJourneyCard({
    super.key,
    required this.journey,
    required this.recordedToday,
    this.onViewChanged,
  });

  final SignalJourney journey;
  final bool recordedToday;
  final VoidCallback? onViewChanged;

  @override
  State<ReturnDayJourneyCard> createState() => _ReturnDayJourneyCardState();
}

class _ReturnDayJourneyCardState extends State<ReturnDayJourneyCard> {
  @override
  void initState() {
    super.initState();
    RetentionMetricsTracker.track(
      RetentionMetricsTracker.returnDayJourneyCardShown,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.recordedToday) {
      return _savedTodayCard(context);
    }
    return _continueCard(context);
  }

  Widget _continueCard(BuildContext context) {
    final body = ConsumerUiCopy.returnDayJourneyBodyTemplate.replaceAll(
      '{title}',
      widget.journey.signalTitle,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ConsumerUiCopy.returnDayJourneyTitle,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () {
              RetentionMetricsTracker.track(
                RetentionMetricsTracker.returnDayJourneyCtaTapped,
              );
              unawaited(
                NextEvidenceReminderService.schedule(
                  journeyId: widget.journey.id,
                  prompt: widget.journey.nextPrompt,
                ),
              );
              SignalJourneyNavigation.recordNextEvidence(
                context,
                prompt: widget.journey.nextPrompt,
              );
            },
            child: const Text(ConsumerUiCopy.returnDayJourneyRecordCta),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: () => SignalJourneyNavigation.openJourneyDetail(context),
            child: const Text(ConsumerUiCopy.returnDayJourneyViewCta),
          ),
        ],
      ),
    );
  }

  Widget _savedTodayCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FFF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ConsumerUiCopy.returnDayEvidenceSavedTitle,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed:
                widget.onViewChanged ??
                () => SignalJourneyNavigation.openJourneyDetail(context),
            child: const Text(ConsumerUiCopy.returnDayEvidenceSavedCta),
          ),
        ],
      ),
    );
  }
}
