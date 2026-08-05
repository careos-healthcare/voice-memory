import 'package:flutter/material.dart';

/// Establishes a named semantic region and deterministic keyboard traversal.
class AccessiblePrimarySurface extends StatelessWidget {
  const AccessiblePrimarySurface({
    super.key,
    required this.label,
    required this.child,
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
