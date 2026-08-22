import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/first_session/day_two_reminder.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Day 2 Gentle Reminder offer — shown once, only after the very first
/// successful save, alongside the Done for today receipt. One accept, one
/// decline, no re-asks. Declining collapses the card quietly.
class DayTwoReminderCard extends StatefulWidget {
  const DayTwoReminderCard({super.key, this.coordinator});

  /// Injectable for tests; production resolves prefs/backend lazily.
  final DayTwoReminderCoordinator? coordinator;

  @override
  State<DayTwoReminderCard> createState() => _DayTwoReminderCardState();
}

enum _CardState { offering, working, scheduled, unavailable, declined }

class _DayTwoReminderCardState extends State<DayTwoReminderCard> {
  _CardState _state = _CardState.offering;

  DayTwoReminderCoordinator get _coordinator =>
      widget.coordinator ?? DayTwoReminderCoordinator();

  Future<void> _accept() async {
    setState(() => _state = _CardState.working);
    final outcome = await _coordinator.accept();
    if (!mounted) return;
    setState(() {
      _state = outcome == DayTwoReminderOutcome.scheduled
          ? _CardState.scheduled
          : _CardState.unavailable;
    });
  }

  Future<void> _decline() async {
    setState(() => _state = _CardState.declined);
    await _coordinator.decline();
  }

  @override
  Widget build(BuildContext context) {
    if (_state == _CardState.declined) return const SizedBox.shrink();

    if (_state == _CardState.offering) {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.day2ReminderPromptSeen,
        entryCount: 1,
        oncePerSession: true,
      );
    }

    final helperStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary);

    return Container(
      key: const Key('day_two_reminder_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF6F4FF),
      ),
      child: switch (_state) {
        _CardState.scheduled => Text(
          DayTwoReminder.scheduledLine,
          key: const Key('day_two_reminder_scheduled'),
          style: helperStyle,
        ),
        _CardState.unavailable => Text(
          DayTwoReminder.unavailableLine,
          key: const Key('day_two_reminder_unavailable'),
          style: helperStyle,
        ),
        _ => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              DayTwoReminder.promptTitle,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              DayTwoReminder.promptBody,
              style: ArchiveMobileTypography.body(
                context,
              ).copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const Key('day_two_reminder_accept'),
              onPressed: _state == _CardState.working ? null : _accept,
              child: const Text(DayTwoReminder.acceptLabel),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              key: const Key('day_two_reminder_decline'),
              onPressed: _state == _CardState.working ? null : _decline,
              child: const Text(DayTwoReminder.declineLabel),
            ),
          ],
        ),
      },
    );
  }
}