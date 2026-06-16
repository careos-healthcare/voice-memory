import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/memory/treat_as_new.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import 'memory_used_indicator.dart';

/// Pre-save "Treat this as new" toggle near the record controls.
///
/// One tap, off by default, per-entry only — not a settings surface.
/// When selected, the next save carries a metadata flag so memory
/// engines leave that entry alone; nothing is deleted or altered and
/// the entry stays findable in the archive.
class TreatAsNewControl extends StatefulWidget {
  const TreatAsNewControl({super.key, this.entryCount});

  /// For analytics counts only.
  final int? entryCount;

  @override
  State<TreatAsNewControl> createState() => _TreatAsNewControlState();
}

class _TreatAsNewControlState extends State<TreatAsNewControl> {
  void _toggle() {
    final next = !TreatAsNew.selectedForNextSave;
    TreatAsNew.selectedForNextSave = next;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.treatAsNewSelected,
      entryCount: widget.entryCount,
      enabled: next,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.treatAsNewSeen,
      entryCount: widget.entryCount,
      oncePerSession: true,
    );

    final selected = TreatAsNew.selectedForNextSave;
    return InkWell(
      key: const Key('treat_as_new_control'),
      onTap: _toggle,
      borderRadius: BorderRadius.circular(VoiceMemoryCards.radius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: VoiceMemoryCards.flat(
          background: selected ? AppColors.accentLight : AppColors.surfaceAlt,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                key: const Key('treat_as_new_toggle'),
                selected
                    ? Icons.check_box_outlined
                    : Icons.check_box_outline_blank,
                size: 20,
                color: selected
                    ? AppColors.accentPrimary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TreatAsNew.controlLabel,
                    style: ArchiveMobileTypography.cardLabel(context),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    TreatAsNew.helper,
                    style: ArchiveMobileTypography.responsiveHelper(
                      context,
                    ).copyWith(color: AppColors.textSecondary),
                  ),
                  if (selected) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      TreatAsNew.expandedHelper,
                      key: const Key('treat_as_new_expanded_helper'),
                      style: ArchiveMobileTypography.responsiveHelper(
                        context,
                      ).copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Post-save receipt shown only when the save carried the flag.
class FreshEntrySavedReceipt extends StatelessWidget {
  const FreshEntrySavedReceipt({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('treat_as_new_receipt'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.flat(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MemoryUsedIndicator(
            connected: false,
            source: 'record_post_save',
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            TreatAsNew.postSaveTitle,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: 2),
          Text(
            TreatAsNew.postSaveBody,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
