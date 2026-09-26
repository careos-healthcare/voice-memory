import 'package:archiveme_mobile/features/health/apple_health_platform.dart';
import 'package:archiveme_mobile/features/health/state_of_mind_reader.dart';
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
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'From Apple Health',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        backgroundColor: _health.withValues(alpha: 0.08),
        side: const BorderSide(color: Color(0x33E85D75)),
      ),
    );
  }
}

/// Looks up that day's State of Mind when the card is shown, then caches it.
/// A stored label is shown immediately. The person's own mood is left alone.
class LazyHealthStateOfMindChip extends StatefulWidget {
  const LazyHealthStateOfMindChip({
    required this.entryId,
    required this.createdAt,
    required this.storedLabel,
    super.key,
  });

  final String entryId;
  final DateTime createdAt;
  final String storedLabel;

  @override
  State<LazyHealthStateOfMindChip> createState() =>
      _LazyHealthStateOfMindChipState();
}

class _LazyHealthStateOfMindChipState extends State<LazyHealthStateOfMindChip> {
  String? _lookedUp;

  @override
  void initState() {
    super.initState();
    if (widget.storedLabel.trim().isEmpty &&
        AppleHealthPlatform.supportsStateOfMind) {
      StateOfMindReader.forDay(widget.createdAt).then((label) {
        if (!mounted) return;
        setState(() => _lookedUp = label);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppleHealthPlatform.isIos) return const SizedBox.shrink();
    final label = widget.storedLabel.trim().isNotEmpty
        ? widget.storedLabel.trim()
        : (_lookedUp ?? '').trim();
    if (label.isEmpty) return const SizedBox.shrink();
    return HealthStateOfMindChip(label: label, entryId: widget.entryId);
  }
}
