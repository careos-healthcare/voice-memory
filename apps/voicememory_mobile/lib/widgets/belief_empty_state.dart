import 'package:flutter/material.dart';

import 'patterns/patterns_empty_view.dart';

/// Delegates to [PatternsEmptyView] — single consumer empty state.
class BeliefEmptyState extends StatelessWidget {
  const BeliefEmptyState({
    super.key,
    this.centered = false,
    this.fillViewport = false,
  });

  final bool centered;
  final bool fillViewport;

  @override
  Widget build(BuildContext context) {
    return PatternsEmptyView(fillViewport: fillViewport);
  }
}
