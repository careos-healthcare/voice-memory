import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/memory/keep_exact_details.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Pre-save "Keep exact details" toggle near the record controls.
///
/// One tap, off by default, per-entry only. When selected, the next
/// save carries a metadata flag so the entry is never compressed into a
/// generic memory summary — it stays evidence with its exact details.
/// Nothing is deleted or altered and the entry stays findable.
class KeepExactDetailsControl extends StatefulWidget {
  const KeepExactDetailsControl({super.key, this.entryCount});

  /// For analytics counts only.
  final int? entryCount;

  @override
  State<KeepExactDetailsControl> createState() =>
      _KeepExactDetailsControlState();
}

class _KeepExactDetailsControlState extends State<KeepExactDetailsControl> {
  void _toggle() {
    final next = !KeepExactDetails.selectedForNextSave;
    KeepExactDetails.selectedForNextSave = next;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.keepExactDetailsSelected,
      entryCount: widget.entryCount,
      enabled: next,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final selected = KeepExactDetails.selectedForNextSave;
    return InkWell(
      key: const Key('keep_exact_details_control'),
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
                key: const Key('keep_exact_details_toggle'),
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
                    KeepExactDetails.controlLabel,
                    style: ArchiveMobileTypography.cardLabel(context),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    KeepExactDetails.helper,
                    style: ArchiveMobileTypography.responsiveHelper(
                      context,
                    ).copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Post-save receipt line shown only when the save carried the flag.
class ExactDetailsSavedReceipt extends StatelessWidget {
  const ExactDetailsSavedReceipt({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('keep_exact_details_receipt'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.flat(background: AppColors.surfaceAlt),
      child: Text(
        KeepExactDetails.savedReceipt,
        style: ArchiveMobileTypography.cardLabel(context),
      ),
    );
  }
}