import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/onboarding/record_return_pro_state.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// C. First archive value card — exactly one entry. Search, pin, record
/// again — no Collections or bulk actions in the first session.
class FirstArchiveValueCard extends StatelessWidget {
  const FirstArchiveValueCard({
    super.key,
    required this.onSearch,
    required this.onRecordAnother,
    this.onPin,
  });

  final VoidCallback onSearch;
  final VoidCallback onRecordAnother;

  /// Null hides pin (already pinned or pins unavailable).
  final VoidCallback? onPin;

  static bool shouldShow(int entryCount) =>
      RecordReturnProGates.showArchiveValue(entryCount: entryCount);

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.firstArchiveValueCardSeen,
      entryCount: 1,
      stage: RecordReturnProStage.archiveValue.id,
      source: 'archive',
      oncePerSession: true,
    );
    return Container(
      key: const Key('first_archive_value_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF6F4FF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            RecordReturnProCopy.archiveTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            RecordReturnProCopy.archiveBody,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('first_archive_search_cta'),
                  onPressed: () {
                    ActivationFunnelAnalytics.track(
                      ActivationFunnelAnalytics.firstArchiveSearchTapped,
                      entryCount: 1,
                      stage: RecordReturnProStage.archiveValue.id,
                      source: 'archive',
                    );
                    onSearch();
                  },
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text(RecordReturnProCopy.archiveSearchAction),
                ),
              ),
              if (onPin != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('first_archive_pin_cta'),
                    onPressed: () {
                      ActivationFunnelAnalytics.track(
                        ActivationFunnelAnalytics.firstArchivePinTapped,
                        entryCount: 1,
                        stage: RecordReturnProStage.archiveValue.id,
                        source: 'archive',
                      );
                      onPin!();
                    },
                    icon: const Icon(Icons.push_pin_outlined, size: 18),
                    label: const Text(RecordReturnProCopy.archivePinAction),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            key: const Key('first_archive_record_another_cta'),
            onPressed: onRecordAnother,
            child: const Text(RecordReturnProCopy.archiveRecordAnother),
          ),
        ],
      ),
    );
  }
}
