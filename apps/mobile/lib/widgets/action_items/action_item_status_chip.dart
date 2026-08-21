import 'package:archiveme_mobile/features/action_items/archive_action_item.dart';
import 'package:flutter/material.dart';

/// Status chip for one action item card.
class ActionItemStatusChip extends StatelessWidget {
  const ActionItemStatusChip({required this.status, super.key});

  final String status;

  String get _label => switch (status) {
    ActionItemStatus.open => 'Open',
    ActionItemStatus.done => 'Done',
    ActionItemStatus.dismissed => 'Dismissed',
    _ => status,
  };

  Color _color(BuildContext context) => switch (status) {
    ActionItemStatus.open => Theme.of(context).colorScheme.primary,
    ActionItemStatus.done => Colors.green.shade700,
    ActionItemStatus.dismissed => Colors.grey,
    _ => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('action_item_status_$status'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color(context).withValues(alpha: 0.4)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _color(context),
        ),
      ),
    );
  }
}