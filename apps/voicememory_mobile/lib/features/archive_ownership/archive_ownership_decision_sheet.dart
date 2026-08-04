import 'package:flutter/material.dart';

import 'archive_ownership_decision_service.dart';

/// The explicit decision the user must make before this account can touch
/// content it has never owned.
///
/// The sheet shows counts and dates only. It never renders a transcript,
/// because the user has not yet agreed to associate that content with this
/// account. There is no default action and no dismiss-to-claim path.
class ArchiveOwnershipDecisionSheet extends StatelessWidget {
  const ArchiveOwnershipDecisionSheet({
    required this.summary,
    required this.onKeepSeparate,
    required this.onMoveToAccount,
    required this.onExport,
    required this.onDelete,
    super.key,
  });

  final UnclaimedArchiveSummary summary;
  final VoidCallback onKeepSeparate;
  final VoidCallback onMoveToAccount;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final moments = summary.momentCount == 1
        ? '1 saved moment'
        : '${summary.momentCount} saved moments';

    return Semantics(
      container: true,
      label: 'Saved moments not yet added to this account',
      child: Material(
        color: colors.surface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  UnclaimedArchiveSummary.prompt,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _rangeLabel(moments),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                _Action(
                  label: 'Keep separate',
                  description:
                      'Leave them on this device, outside this account.',
                  onPressed: onKeepSeparate,
                ),
                _Action(
                  label: 'Move to this account',
                  description: 'Ask again to confirm before anything moves.',
                  onPressed: onMoveToAccount,
                ),
                _Action(
                  label: 'Export',
                  description: 'Save a copy you keep yourself.',
                  onPressed: onExport,
                ),
                _Action(
                  label: 'Delete',
                  description: 'Remove them from this device for good.',
                  isDestructive: true,
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _rangeLabel(String moments) {
    final earliest = summary.earliestAt;
    final latest = summary.latestAt;
    if (earliest == null || latest == null) return moments;
    return '$moments, ${_date(earliest)} to ${_date(latest)}.';
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.description,
    required this.onPressed,
    this.isDestructive = false,
  });

  final String label;
  final String description;
  final VoidCallback onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = isDestructive ? colors.error : colors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(color: foreground),
              ),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
