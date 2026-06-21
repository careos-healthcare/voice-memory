import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_proof/archive_paid_value_proof_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Copy-only paid value proof — no billing UI or entitlement changes.
class ArchivePaidValueProofCard extends StatelessWidget {
  const ArchivePaidValueProofCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('archive_paid_value_proof_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF6F4FF),
      ),
      child: Text(
        ArchivePaidValueProofCopy.body,
        style: ArchiveMobileTypography.body(context).copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
