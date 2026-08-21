import 'package:flutter/material.dart';

/// Establishes a named semantic region and deterministic keyboard traversal.
class AccessiblePrimarySurface extends StatelessWidget {
  const AccessiblePrimarySurface({
    required this.label, required this.child, super.key,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: label,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: child,
      ),
    );
  }
}