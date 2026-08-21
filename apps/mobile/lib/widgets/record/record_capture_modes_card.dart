import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/record_capture_modes/record_capture_mode_copy.dart';
import 'package:archiveme_mobile/features/record_capture_modes/record_capture_mode_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Permissive capture mode chips below Record capture CTAs.
class RecordCaptureModesCard extends StatelessWidget {
  const RecordCaptureModesCard({required this.onModeTap, super.key});

  final ValueChanged<RecordCaptureMode> onModeTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('record_capture_modes_card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          RecordCaptureModeCopy.cardTitle,
          key: const Key('record_capture_modes_title'),
          style: ArchiveMobileTypography.cardLabel(
            context,
          ).copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          RecordCaptureModeCopy.cardSubtitle,
          key: const Key('record_capture_modes_subtitle'),
          style: ArchiveMobileTypography.explanationBody(
            context,
          ).copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final mode in RecordCaptureMode.all)
              _CaptureModeChip(
                key: Key('record_capture_mode_${mode.id.name}'),
                label: mode.label,
                onTap: () => onModeTap(mode),
              ),
          ],
        ),
      ],
    );
  }
}

class _CaptureModeChip extends StatelessWidget {
  const _CaptureModeChip({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
  }
}