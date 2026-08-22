import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/early_archive/archive_watching_engine.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Small status line — what the archive is currently watching.
class ArchiveWatchingMicroState extends StatelessWidget {
  const ArchiveWatchingMicroState({required this.watching, super.key});

  final ArchiveWatchingResult watching;

  @override
  Widget build(BuildContext context) {
    final style = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.35,
      fontSize: 12,
      fontStyle: FontStyle.italic,
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        watching.line,
        key: const Key('archive_watching_micro_state'),
        style: style,
      ),
    );
  }
}