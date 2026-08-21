import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_priority_decision.dart';
import 'package:archiveme_mobile/features/memory/not_important_feedback.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Demotes priority for a memory card without marking it unrelated.
class NotImportantAction extends StatefulWidget {
  const NotImportantAction({required this.cardType, super.key, this.onMarked});

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