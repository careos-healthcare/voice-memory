import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/activation/day_two_return_loop_payoff.dart';
import '../../features/first_session/day_two_reminder.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// One calm return action after save — replaces scattered preview/reminder cards.
class DayTwoReturnLoopCard extends StatefulWidget {
  const DayTwoReturnLoopCard({
    super.key,
    required this.payoff,
    required this.onAddAnother,
    required this.onViewArchive,
    this.reminderCoordinator,
    this.onReminderAccepted,
    this.onReminderDeclined,
  });

  final DayTwoReturnLoopPayoff payoff;
  final VoidCallback onAddAnother;
  final VoidCallback onViewArchive;
  final DayTwoReminderCoordinator? reminderCoordinator;
  final VoidCallback? onReminderAccepted;
  final VoidCallback? onReminderDeclined;

  @override
  State<DayTwoReturnLoopCard> createState() => _DayTwoReturnLoopCardState();
}

class _DayTwoReturnLoopCardState extends State<DayTwoReturnLoopCard> {
  DayTwoReminderOutcome? _reminderOutcome;
  bool _reminderDeclined = false;
  bool _reminderWorking = false;

  DayTwoReminderCoordinator get _coordinator =>
      widget.reminderCoordinator ?? DayTwoReminderCoordinator();

  Future<void> _acceptReminder() async {
    setState(() => _reminderWorking = true);
    final outcome = await _coordinator.accept();
    if (!mounted) return;
    setState(() {
      _reminderWorking = false;
      _reminderOutcome = outcome;
    });
    widget.onReminderAccepted?.call();
  }

  Future<void> _declineReminder() async {
    setState(() => _reminderDeclined = true);
    await _coordinator.decline();
    widget.onReminderDeclined?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final footnoteStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );

    return Container(
      key: const Key('day_two_return_loop_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8F6F2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.payoff.body,
            key: const Key('day_two_return_loop_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('day_two_return_loop_add_cta'),
            onPressed: widget.onAddAnother,
            child: Text(widget.payoff.primaryCta),
          ),
          if (widget.payoff.secondaryCta case final secondary?) ...[
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              key: const Key('day_two_return_loop_view_archive_cta'),
              onPressed: widget.onViewArchive,
              child: Text(secondary),
            ),
          ],
          if (widget.payoff.offerReminder &&
              !_reminderDeclined &&
              _reminderOutcome == null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              DayTwoReminder.promptTitle,
              key: const Key('day_two_return_loop_reminder_title'),
              style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              DayTwoReminder.promptBody,
              key: const Key('day_two_return_loop_reminder_body'),
              style: bodyStyle.copyWith(fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const Key('day_two_return_loop_reminder_accept'),
              onPressed: _reminderWorking ? null : _acceptReminder,
              child: const Text(DayTwoReminder.acceptLabel),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              key: const Key('day_two_return_loop_reminder_decline'),
              onPressed: _reminderWorking ? null : _declineReminder,
              child: const Text(DayTwoReminder.declineLabel),
            ),
          ],
          if (_reminderOutcome == DayTwoReminderOutcome.scheduled) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              DayTwoReminder.scheduledLine,
              key: const Key('day_two_return_loop_reminder_scheduled'),
              style: footnoteStyle,
            ),
          ] else if (_reminderOutcome != null &&
              _reminderOutcome != DayTwoReminderOutcome.scheduled) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              DayTwoReminder.unavailableLine,
              key: const Key('day_two_return_loop_reminder_unavailable'),
              style: footnoteStyle,
            ),
          ],
        ],
      ),
    );
  }
}
