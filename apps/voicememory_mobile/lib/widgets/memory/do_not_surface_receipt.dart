import 'package:flutter/material.dart';

import '../../features/memory/memory_surfacing_mode.dart';
import '../../theme/app_spacing.dart';

/// Receipt after saving with Do not surface selected.
class DoNotSurfaceReceipt extends StatelessWidget {
  const DoNotSurfaceReceipt({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('do_not_surface_receipt'),
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        MemorySurfacingCopy.doNotSurfaceReceipt,
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}
