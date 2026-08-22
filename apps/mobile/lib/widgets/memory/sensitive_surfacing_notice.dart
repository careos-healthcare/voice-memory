import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/memory/memory_surfacing_mode.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Cautious notice when sensitive content appears in user-initiated review.
class SensitiveSurfacingNotice extends StatelessWidget {
  const SensitiveSurfacingNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('sensitive_surfacing_notice'),
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        MemorySurfacingCopy.sensitiveHelper,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}