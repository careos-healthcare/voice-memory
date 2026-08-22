import 'package:archiveme_mobile/widgets/patterns/patterns_empty_view.dart';
import 'package:flutter/material.dart';

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