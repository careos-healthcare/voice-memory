import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_proof/visible_archive_proof_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Three-step visual promise on Record before the first save — scannable in seconds.
class RecordTopArchivePromiseHero extends StatelessWidget {
  const RecordTopArchivePromiseHero({super.key});

  @override
  Widget build(BuildContext context) {
    final stepStyle = ArchiveMobileTypography.listTitle(context).copyWith(
      fontSize: 15,
      height: 1.35,
    );
    final numberStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.accentPrimary,
      fontWeight: FontWeight.w700,
      fontSize: 13,
    );

    return Container(
      key: const Key('record_top_archive_promise_hero'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8F5),
        borderRadius: BorderRadius.circular(VoiceMemoryCards.radius),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: VoiceMemoryCards.standard().boxShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < VisibleArchiveProofCopy.firstRunPromiseSteps.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  key: Key('record_promise_step_badge_$i'),
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentPrimary.withValues(alpha: 0.12),
                  ),
                  child: Text('${i + 1}', style: numberStyle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    VisibleArchiveProofCopy.firstRunPromiseSteps[i],
                    key: Key('record_promise_step_$i'),
                    style: stepStyle,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
