import 'dart:async';

import 'package:flutter/material.dart';

/// Short breath-pacing step shown before grounded hook responses unlock.
class GroundingBreathSpacer extends StatefulWidget {
  const GroundingBreathSpacer({
    super.key,
    required this.onPacingComplete,
    this.pacingDuration = const Duration(seconds: 4),
  });

  final VoidCallback onPacingComplete;
  final Duration pacingDuration;

  @override
  State<GroundingBreathSpacer> createState() => _GroundingBreathSpacerState();
}

class _GroundingBreathSpacerState extends State<GroundingBreathSpacer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.pacingDuration <= Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _completePacing());
      return;
    }
    _timer = Timer(widget.pacingDuration, _completePacing);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _completePacing() {
    if (!mounted) return;
    widget.onPacingComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      key: const Key('grounding_breath_spacer'),
      label: 'Grounding breath pacing',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Take one slow breath',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'In through your nose, out through your mouth.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: theme.colorScheme.outlineVariant.withValues(
                alpha: 0.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
