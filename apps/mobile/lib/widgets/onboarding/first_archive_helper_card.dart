import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/onboarding/first_60_second_state.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// E. First archive view — a small helper for users with exactly one
/// entry. It points at the existing next steps (search, pin, return
/// tomorrow) and nothing else: no Collections, no bulk actions, no memory
/// controls in the first session.
class FirstArchiveHelperCard extends StatelessWidget {
  const FirstArchiveHelperCard({required this.onSearch, super.key, this.onPin});

  /// Focuses the existing archive search input.
  final VoidCallback onSearch;

  /// Pins the single entry via the existing pin flow. Null hides the pin
  /// action (pins unavailable, or the entry is already pinned).
  final VoidCallback? onPin;

  /// Exactly one active entry.
  static bool shouldShow(int entryCount) =>
      First60Gates.showArchiveHelper(entryCount: entryCount);

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.first60ArchiveOpened,
      entryCount: 1,
      stage: First60Stage.archiveHelper.id,
      source: 'archive',
      oncePerSession: true,
    );
    return Container(
      key: const Key('first_60_archive_helper_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF6F4FF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            First60Copy.helperTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            First60Copy.helperBody,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('first_60_helper_search'),
                  onPressed: onSearch,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text(First60Copy.helperSearchAction),
                ),
              ),
              if (onPin != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('first_60_helper_pin'),
                    onPressed: onPin,
                    icon: const Icon(Icons.push_pin_outlined, size: 18),
                    label: const Text(First60Copy.helperPinAction),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}