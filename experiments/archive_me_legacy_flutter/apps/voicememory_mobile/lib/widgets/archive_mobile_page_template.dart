import 'package:flutter/material.dart';

import '../design/archive_mobile_spacing.dart';
import '../design/archive_mobile_typography.dart';
import '../theme/app_colors.dart';
import 'archive_explanation_card.dart';

/// Shared archive experience layout — light scaffold, generous spacing.
class ArchiveMobilePageTemplate extends StatelessWidget {
  const ArchiveMobilePageTemplate({
    super.key,
    required this.eyebrow,
    required this.title,
    this.lead,
    this.currentArchiveState,
    this.whatChanged,
    required this.mainContent,
    this.supportingContent,
    this.actionArea,
    this.onRefresh,
    this.backgroundColor,
    this.showArchiveExplanation = false,
  });

  final String eyebrow;
  final String title;
  final String? lead;
  final Widget? currentArchiveState;
  final Widget? whatChanged;
  final Widget mainContent;
  final Widget? supportingContent;
  final Widget? actionArea;
  final Future<void> Function()? onRefresh;
  final Color? backgroundColor;
  final bool showArchiveExplanation;

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: ArchiveMobileSpacing.pagePadding,
      children: [
        if (showArchiveExplanation) ...[
          const ArchiveExplanationCard(),
          const SizedBox(height: ArchiveMobileSpacing.md),
        ],
        Text(eyebrow, style: ArchiveMobileTypography.eyebrow(context)),
        const SizedBox(height: ArchiveMobileSpacing.sm),
        Text(title, style: ArchiveMobileTypography.pageTitle(context)),
        if (lead != null) ...[
          const SizedBox(height: ArchiveMobileSpacing.sm),
          Text(lead!, style: ArchiveMobileTypography.body(context)),
        ],
        if (currentArchiveState != null) ...[
          const SizedBox(height: ArchiveMobileSpacing.md),
          currentArchiveState!,
        ],
        if (whatChanged != null) ...[
          const SizedBox(height: ArchiveMobileSpacing.md),
          whatChanged!,
        ],
        const SizedBox(height: ArchiveMobileSpacing.lg),
        mainContent,
        if (supportingContent != null) ...[
          const SizedBox(height: ArchiveMobileSpacing.lg),
          supportingContent!,
        ],
        if (actionArea != null) ...[
          const SizedBox(height: ArchiveMobileSpacing.lg),
          Align(alignment: Alignment.centerRight, child: actionArea!),
        ],
        const SizedBox(height: ArchiveMobileSpacing.xl),
      ],
    );

    final scrollable = onRefresh == null
        ? body
        : RefreshIndicator(onRefresh: onRefresh!, child: body);

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.backgroundPrimary,
      body: SafeArea(child: scrollable),
    );
  }
}
