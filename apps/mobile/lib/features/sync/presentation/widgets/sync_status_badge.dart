import 'package:flutter/material.dart';

/// Compact sync badge. Const so phone and desktop shells can mount it.
class SyncStatusBadgeSlot extends StatelessWidget {
  const SyncStatusBadgeSlot({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
