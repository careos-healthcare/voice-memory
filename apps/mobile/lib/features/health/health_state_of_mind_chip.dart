import 'package:flutter/material.dart';

/// Read-only Apple Health State of Mind. It never edits the person's mood.
class HealthStateOfMindChip extends StatelessWidget {
  const HealthStateOfMindChip({
    required this.label,
    required this.entryId,
    super.key,
  });

  final String label;
  final String entryId;

  static const _health = Color(0xFFE85D75);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Apple Health State of Mind, $label',
      child: Chip(
        key: Key('health_state_of_mind_$entryId'),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.only(left: 2, right: 8),
        avatar: const Icon(Icons.favorite_border, size: 12, color: _health),
        label: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: _health.withValues(alpha: 0.08),
        side: const BorderSide(color: Color(0x33E85D75)),
      ),
    );
  }
}
