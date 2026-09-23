import 'package:archiveme_mobile/core/theme/serene_theme.dart';
import 'package:archiveme_mobile/models/ambient_context.dart';
import 'package:flutter/material.dart';

/// One quiet line of place, weather, steps, and the current calendar title.
class AmbientContextPills extends StatelessWidget {
  const AmbientContextPills({required this.ambient, super.key});

  final AmbientContext ambient;

  @override
  Widget build(BuildContext context) {
    final label = ambient.pillText;
    if (label == null) return const SizedBox.shrink();
    final theme = SereneTheme.overlay(Theme.of(context));
    return SereneEntrance(
      child: DecoratedBox(
        key: const Key('ambient_context_pills'),
        decoration: BoxDecoration(
          gradient: SereneTheme.canvas,
          borderRadius: BorderRadius.circular(999),
          boxShadow: SereneTheme.softShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge,
          ),
        ),
      ),
    );
  }
}
