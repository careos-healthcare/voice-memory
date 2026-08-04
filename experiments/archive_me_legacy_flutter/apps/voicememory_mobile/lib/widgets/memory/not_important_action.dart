import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/memory/memory_control_model.dart';
import '../../features/memory/memory_priority_decision.dart';
import '../../features/memory/not_important_feedback.dart';
import '../../theme/app_colors.dart';

/// Demotes priority for a memory card without marking it unrelated.
class NotImportantAction extends StatefulWidget {
  const NotImportantAction({super.key, required this.cardType, this.onMarked});

  final MemoryCardType cardType;
  final VoidCallback? onMarked;

  @override
  State<NotImportantAction> createState() => _NotImportantActionState();
}

class _NotImportantActionState extends State<NotImportantAction> {
  var _thanked = false;

  void _markNotImportant() {
    NotImportantFeedback.markNotImportant(widget.cardType);
    setState(() => _thanked = true);
    widget.onMarked?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_thanked) {
      return Padding(
        key: Key('not_important_thanks_${widget.cardType.id}'),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          MemoryPriorityCopy.notImportantThanks,
          style: ArchiveMobileTypography.responsiveHelper(
            context,
          ).copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    return TextButton(
      key: Key('not_important_action_${widget.cardType.id}'),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: AppColors.textSecondary,
      ),
      onPressed: _markNotImportant,
      child: Text(
        MemoryPriorityCopy.notImportantLabel,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }
}
