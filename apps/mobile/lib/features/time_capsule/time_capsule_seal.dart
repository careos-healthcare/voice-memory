import 'package:archiveme_mobile/core/user/progressive_disclosure.dart';
import 'package:archiveme_mobile/models/time_capsule_lock.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Whether a sealed moment is still closed, and how long until it can open.
final class TimeCapsuleSealEvaluation {
  const TimeCapsuleSealEvaluation({
    required this.sealed,
    required this.locked,
    this.daysRemaining,
    this.entriesRemaining,
  });

  const TimeCapsuleSealEvaluation.unsealed()
    : sealed = false,
      locked = false,
      daysRemaining = null,
      entriesRemaining = null;

  /// A capsule stays locked until its date arrives or the milestone count is
  /// reached. The badge names whichever gates are still closed.
  factory TimeCapsuleSealEvaluation.evaluate({
    required TimeCapsuleLock lock,
    required UserMilestoneSnapshot milestones,
    required DateTime now,
  }) {
    if (!lock.isTimeCapsule) {
      return const TimeCapsuleSealEvaluation.unsealed();
    }
    final nowMillis = now.toUtc().millisecondsSinceEpoch;
    final unlocked = lock.isUnlocked(
      nowMillis: nowMillis,
      activeEntryCount: milestones.journalEntryCount,
    );
    if (unlocked) {
      return const TimeCapsuleSealEvaluation(sealed: true, locked: false);
    }

    int? daysRemaining;
    final unlockDate = lock.unlockDateMillis;
    if (unlockDate != null && unlockDate > nowMillis) {
      final remaining = Duration(milliseconds: unlockDate - nowMillis);
      daysRemaining = remaining.inDays < 1 ? 1 : remaining.inDays;
    }

    int? entriesRemaining;
    final milestone = lock.unlockMilestoneEntryCount;
    if (milestone != null && milestones.journalEntryCount < milestone) {
      entriesRemaining = milestone - milestones.journalEntryCount;
    }

    return TimeCapsuleSealEvaluation(
      sealed: true,
      locked: true,
      daysRemaining: daysRemaining,
      entriesRemaining: entriesRemaining,
    );
  }

  final bool sealed;
  final bool locked;
  final int? daysRemaining;
  final int? entriesRemaining;

  String get badgeLabel {
    final days = daysRemaining;
    final entries = entriesRemaining;
    if (days != null && entries != null) {
      return 'Locked · opens in $days ${days == 1 ? 'day' : 'days'}, '
          'or after $entries more ${entries == 1 ? 'moment' : 'moments'}';
    }
    if (days != null) {
      return 'Locked · opens in $days ${days == 1 ? 'day' : 'days'}';
    }
    if (entries != null) {
      return 'Locked · opens after $entries more '
          '${entries == 1 ? 'moment' : 'moments'}';
    }
    return 'Locked';
  }
}

/// Seal control for one saved moment. Shows a countdown badge while locked.
class TimeCapsuleSealCard extends StatelessWidget {
  const TimeCapsuleSealCard({
    required this.lock,
    required this.milestones,
    required this.now,
    this.onSeal,
    super.key,
  });

  final TimeCapsuleLock lock;
  final UserMilestoneSnapshot milestones;
  final DateTime now;
  final VoidCallback? onSeal;

  @override
  Widget build(BuildContext context) {
    final evaluation = TimeCapsuleSealEvaluation.evaluate(
      lock: lock,
      milestones: milestones,
      now: now,
    );
    return Column(
      key: const Key('time_capsule_seal'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (evaluation.locked)
          Container(
            key: const Key('time_capsule_locked_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.accent),
            ),
            child: Text(
              evaluation.badgeLabel,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else if (evaluation.sealed)
          const Text('Opened')
        else
          TextButton(
            key: const Key('time_capsule_seal_button'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
            ),
            onPressed: onSeal,
            child: const Text('Seal for later'),
          ),
      ],
    );
  }
}
