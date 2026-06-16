import 'package:flutter/material.dart';

import '../../features/memory/memory_surfacing_mode.dart';
import '../../theme/app_spacing.dart';

/// Receipt after saving with Sensitive selected.
class SensitiveSurfacingReceipt extends StatelessWidget {
  const SensitiveSurfacingReceipt({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('sensitive_surfacing_receipt'),
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        MemorySurfacingCopy.sensitiveReceipt,
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}
