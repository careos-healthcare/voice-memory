import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/private_archive_report_analytics.dart';
import '../../features/early_archive/private_archive_report_copy.dart';
import '../../features/early_archive/private_archive_report_gates.dart';
import '../../features/early_archive/private_archive_report_model.dart';
import '../../features/private_report/private_report_copy.dart';
import '../../features/share/archive_share_actions.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Full private archive report in a bottom sheet.
class PrivateReportSheet extends StatelessWidget {
  const PrivateReportSheet({
    super.key,
    required this.report,
    required this.entryCount,
    required this.surface,
    required this.isPro,
    this.onCopy,
  });

  final PrivateArchiveReport report;
  final int entryCount;
  final String surface;
  final bool isPro;
  final Future<bool> Function(String text)? onCopy;

  static Future<void> show(
    BuildContext context, {
    required PrivateArchiveReport report,
    required int entryCount,
    required String surface,
    required bool isPro,
    Future<bool> Function(String text)? onCopy,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: PrivateReportSheet(
          report: report,
          entryCount: entryCount,
          surface: surface,
          isPro: isPro,
          onCopy: onCopy,
        ),
      ),
    );
  }

  bool get _isFullExport => PrivateArchiveReportGates.showFullExport(isPro: isPro);

  String get _exportText => report.visiblePlainText(
        isPro: _isFullExport,
        previewSectionCount: report.previewSectionCount,
      );

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final fallbackStyle = bodyStyle.copyWith(
      color: AppColors.textSecondary,
      fontStyle: FontStyle.italic,
    );
    final labelStyle = ArchiveMobileTypography.cardLabel(context);
    final secondaryStyle = bodyStyle.copyWith(color: AppColors.textSecondary);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            key: const Key('private_report_sheet'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                report.title,
                key: const Key('private_report_sheet_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                report.intro,
                key: const Key('private_report_sheet_subtitle'),
                style: secondaryStyle,
              ),
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < report.sections.length; i++)
                if (PrivateArchiveReportGates.includeSectionInPreview(
                  sectionIndex: i,
                  isPro: _isFullExport,
                  previewSectionCount: report.previewSectionCount,
                ))
                  _SectionBlock(
                    section: report.sections[i],
                    labelStyle: labelStyle,
                    bodyStyle: bodyStyle,
                    fallbackStyle: fallbackStyle,
                  ),
              if (PrivateArchiveReportGates.showPreviewNote(isPro: isPro)) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  PrivateArchiveReportCopy.previewTitle,
                  key: const Key('private_report_sheet_preview_title'),
                  style: ArchiveMobileTypography.listTitle(context).copyWith(
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  PrivateArchiveReportCopy.previewBody,
                  key: const Key('private_report_sheet_preview_body'),
                  style: secondaryStyle,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              _ScopeList(
                heading: PrivateReportCopy.includedHeading,
                items: PrivateReportCopy.includedItems,
                headingKey: const Key('private_report_sheet_included_heading'),
                listKey: const Key('private_report_sheet_included'),
                labelStyle: labelStyle,
                bodyStyle: secondaryStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              _ScopeList(
                heading: PrivateReportCopy.notIncludedHeading,
                items: PrivateReportCopy.notIncludedItems,
                headingKey:
                    const Key('private_report_sheet_not_included_heading'),
                listKey: const Key('private_report_sheet_not_included'),
                labelStyle: labelStyle,
                bodyStyle: secondaryStyle,
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('private_report_sheet_copy_cta'),
                  onPressed: () => _copy(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentPrimary,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(PrivateReportCopy.copyReportCta),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('private_report_sheet_close_cta'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(PrivateReportCopy.closeCta),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    PrivateArchiveReportAnalytics.copyTapped(
      surface: surface,
      entryCount: entryCount,
      isFullExport: _isFullExport,
    );
    if (onCopy != null) {
      await onCopy!(_exportText);
      return;
    }
    final outcome = await ArchiveShareActions.copyShareText(
      context,
      text: _exportText,
      showConfirmation: false,
    );
    if (!context.mounted) return;
    if (outcome == ArchiveShareOutcome.copied) {
      ArchiveShareActions.showFeedback(
        context,
        PrivateReportCopy.copySuccess,
      );
    }
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.section,
    required this.labelStyle,
    required this.bodyStyle,
    required this.fallbackStyle,
  });

  final PrivateArchiveReportSection section;
  final TextStyle labelStyle;
  final TextStyle bodyStyle;
  final TextStyle fallbackStyle;

  @override
  Widget build(BuildContext context) {
    final isFallback = section.lines.any(
      (line) => line.trim() == PrivateReportCopy.notEnoughEvidence,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            section.heading,
            key: Key('private_report_sheet_section_${section.heading}'),
            style: labelStyle,
          ),
          for (final line in section.lines)
            if (line.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  line,
                  style: isFallback ? fallbackStyle : bodyStyle,
                ),
              ),
          for (final bullet in section.bullets)
            if (bullet.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('- $bullet', style: bodyStyle),
              ),
        ],
      ),
    );
  }
}

class _ScopeList extends StatelessWidget {
  const _ScopeList({
    required this.heading,
    required this.items,
    required this.headingKey,
    required this.listKey,
    required this.labelStyle,
    required this.bodyStyle,
  });

  final String heading;
  final List<String> items;
  final Key headingKey;
  final Key listKey;
  final TextStyle labelStyle;
  final TextStyle bodyStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: listKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(heading, key: headingKey, style: labelStyle),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('- $item', style: bodyStyle),
          ),
      ],
    );
  }
}
