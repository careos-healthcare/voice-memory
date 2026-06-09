import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/reminders/reminder_timing_engine.dart';
import '../../features/reminders/reminder_timing_model.dart';
import '../../features/reminders/reminder_timing_store.dart';
import '../../features/retention/next_evidence_reminder_service.dart';
import '../../features/retention/reminder_pre_prompt_coordinator.dart';
import '../../features/retention/retention_metrics_tracker.dart';
import '../../features/routine/routine_anchor_model.dart';
import '../../features/loop_mode/loop_mode_coordinator.dart';
import '../../features/signal_journey/signal_journey_coordinator.dart';
import '../../product/loop_mode_copy.dart';
import '../../features/tomorrow_return/check_in_reminder_service.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Pre-permission explanation with reminder timing experiment.
Future<void> maybeOfferReminderPrePrompt(
  BuildContext context, {
  required ReminderPrePromptTrigger trigger,
  String? prompt,
  RoutineAnchor? routineAnchor,
}) async {
  final should = await ReminderPrePromptCoordinator.shouldShow(trigger);
  if (!should || !context.mounted) return;

  await ReminderPrePromptCoordinator.markShown();
  await RetentionMetricsTracker.track(
    RetentionMetricsTracker.reminderPrePromptShown,
  );

  final choice = await showModalBottomSheet<_ReminderSheetResult>(
    context: context,
    backgroundColor: AppColors.backgroundPrimary,
    isScrollControlled: true,
    builder: (ctx) => _ReminderPrePromptSheet(
      routineAnchor: routineAnchor,
      prompt: prompt,
    ),
  );
  if (choice == null || !context.mounted) return;

  if (choice.dismissed) {
    await ReminderPrePromptCoordinator.markDismissed();
    await ReminderTimingStore.instance().recordDismissed();
    await RetentionMetricsTracker.track(
      RetentionMetricsTracker.reminderDismissedTapped,
    );
    return;
  }

  final variant = choice.variant;
  if (variant == null) return;

  await ReminderTimingStore.instance().recordSelected(variant);
  await RetentionMetricsTracker.track(
    RetentionMetricsTracker.reminderAllowedTapped,
  );

  await CheckInReminderService.ensureInitialized();
  if (!CheckInReminderService.backend.isAvailable) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ConsumerUiCopy.reminderNotAvailableInBuild),
        ),
      );
    }
    return;
  }

  final granted = await CheckInReminderService.requestPermissionOnly();
  if (!granted) return;

  final journey = await SignalJourneyCoordinator.loadActive();
  if (journey == null) return;

  const engine = ReminderTimingEngine();
  final plan = engine.plan(
    journeyId: journey.id,
    variant: variant,
    prompt: prompt ?? journey.nextPrompt,
    routineAnchor: routineAnchor,
  );

  final outcome = await NextEvidenceReminderService.schedule(
    journeyId: journey.id,
    prompt: prompt ?? journey.nextPrompt,
    when: plan.when,
  );

  if (outcome == ReminderScheduleOutcome.notAvailable && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(ConsumerUiCopy.reminderNotAvailableInBuild),
      ),
    );
  }
}

class _ReminderSheetResult {
  const _ReminderSheetResult({this.variant, this.dismissed = false});

  final ReminderTimingVariant? variant;
  final bool dismissed;
}

class _ReminderPrePromptSheet extends StatefulWidget {
  const _ReminderPrePromptSheet({this.routineAnchor, this.prompt});

  final RoutineAnchor? routineAnchor;
  final String? prompt;

  @override
  State<_ReminderPrePromptSheet> createState() => _ReminderPrePromptSheetState();
}

class _ReminderPrePromptSheetState extends State<_ReminderPrePromptSheet> {
  bool _pickTiming = false;
  late final List<ReminderTimingVariant> _variants;
  String _title = ConsumerUiCopy.reminderPrePromptTitle;
  String _body = ConsumerUiCopy.reminderPrePromptBody;

  @override
  void initState() {
    super.initState();
    _variants = const ReminderTimingEngine().offeredVariants(
      routineAnchor: widget.routineAnchor,
    );
    unawaited(ReminderTimingStore.instance().recordOffered(_variants));
    unawaited(_loadLoopCopy());
  }

  Future<void> _loadLoopCopy() async {
    final loop = await LoopModeCoordinator.loadActive();
    if (!mounted || loop == null || !loop.isFullyImplementedLoop) return;
    setState(() {
      if (loop.isCapacityYes) {
        _title = LoopModeCopy.capacityReminderPrePromptTitle;
        _body = LoopModeCopy.capacityReminderPrePromptBody;
      } else if (loop.isProveEnough) {
        _title = LoopModeCopy.proveEnoughReminderPrePromptTitle;
        _body = LoopModeCopy.proveEnoughReminderPrePromptBody;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _body,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!_pickTiming) ...[
              FilledButton(
                onPressed: () => setState(() => _pickTiming = true),
                child: const Text(ConsumerUiCopy.reminderPrePromptAllowCta),
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton(
                onPressed: () => Navigator.pop(
                  context,
                  const _ReminderSheetResult(dismissed: true),
                ),
                child: const Text(ConsumerUiCopy.reminderPrePromptDismissCta),
              ),
            ] else ...[
              for (final variant in _variants.where(
                (v) => v != ReminderTimingVariant.routineAnchor,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _ReminderSheetResult(variant: variant),
                    ),
                    child: Text(variant.label),
                  ),
                ),
              if (_variants.contains(ReminderTimingVariant.routineAnchor))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      const _ReminderSheetResult(
                        variant: ReminderTimingVariant.routineAnchor,
                      ),
                    ),
                    child: Text(ReminderTimingVariant.routineAnchor.label),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
