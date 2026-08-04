import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/memory/memory_authority_frame.dart';
import '../../features/memory/memory_authority_framing_engine.dart';
import '../../features/memory/memory_control_model.dart';
import '../../theme/app_colors.dart';
import 'memory_authority_framing_sheet.dart';
import 'memory_evidence_inspect_sheet.dart';

/// The compact authority-frame row on a memory card: the authority label
/// for the evidence behind the card, plus the "How this memory was used"
/// explanation action.
///
/// Renders nothing when no frame exists for [cardType] or when the
/// frame's influence does not permit connection claims — a card whose
/// evidence was suppressed has no frame to explain because the card
/// itself never renders.
class MemoryAuthorityFrameCard extends StatelessWidget {
  const MemoryAuthorityFrameCard({super.key, required this.cardType});

  final MemoryCardType cardType;

  @override
  Widget build(BuildContext context) {
    final frame = MemoryAuthorityFrameLog.frameFor(cardType);
    if (frame == null || !frame.allowsConnectionClaims) {
      return const SizedBox.shrink();
    }

    return Wrap(
      key: Key('memory_authority_frame_${cardType.id}'),
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Text(
            frame.authorityState.label,
            key: Key('memory_authority_state_${cardType.id}'),
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          key: Key('memory_authority_framing_action_${cardType.id}'),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundColor: AppColors.textSecondary,
          ),
          onPressed: () => MemoryAuthorityFramingSheet.show(context, frame),
          child: Text(
            MemoryAuthorityCopy.actionLabel,
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          key: Key('memory_show_evidence_action_${cardType.id}'),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundColor: AppColors.textSecondary,
          ),
          onPressed: () => MemoryEvidenceInspectSheet.show(context, cardType),
          child: Text(
            MemoryEvidenceInspectCopy.actionLabel,
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
