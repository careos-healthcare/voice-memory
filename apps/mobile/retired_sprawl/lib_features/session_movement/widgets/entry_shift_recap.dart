import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/session_movement/session_movement_copy.dart';
import 'package:archiveme_mobile/features/session_movement/session_movement_models.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Post-entry recap widget — fires immediately after save (web SessionMovementSummary parity).
class EntryShiftRecap extends StatefulWidget {
  const EntryShiftRecap({
    required this.summary, super.key,
  });

  final SessionMovementSummaryView summary;

  @override
  State<EntryShiftRecap> createState() => _EntryShiftRecapState();
}

class _EntryShiftRecapState extends State<EntryShiftRecap> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;

    return Container(
      key: const Key('entry_shift_recap'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            SessionMovementCopy.heading,
            style: ArchiveMobileTypography.cardLabel(context).copyWith(
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            summary.headline,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          if (summary.detailLine != null) ...[
            const SizedBox(height: 4),
            Text(
              summary.detailLine!,
              style: ArchiveMobileTypography.explanationBody(context).copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: const Text(SessionMovementCopy.whyMoved),
          ),
          if (_expanded)
            Text(
              summary.reason,
              style: ArchiveMobileTypography.explanationBody(context).copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}