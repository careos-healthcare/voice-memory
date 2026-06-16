import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/memory/memory_priority_decision.dart';
import '../../theme/app_colors.dart';

/// Compact badge showing priority band when memory is used cautiously.
class MemoryPriorityBadge extends StatelessWidget {
  const MemoryPriorityBadge({super.key, required this.priority});

  final MemoryPriorityDecision priority;

  String get _label => switch (priority.priorityBand) {
    MemoryPriorityBand.essential => 'Essential evidence',
    MemoryPriorityBand.important => 'Important evidence',
    MemoryPriorityBand.normal => 'Related evidence',
    MemoryPriorityBand.background => 'Background evidence',
    MemoryPriorityBand.suppressed => 'Suppressed',
  };

  @override
  Widget build(BuildContext context) {
    if (priority.priorityBand == MemoryPriorityBand.suppressed) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        _label,
        key: Key('memory_priority_badge_${priority.priorityBand.id}'),
        style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
          color: AppColors.textSecondary,
          fontStyle: priority.backgroundOnly ? FontStyle.italic : null,
        ),
      ),
    );
  }
}
