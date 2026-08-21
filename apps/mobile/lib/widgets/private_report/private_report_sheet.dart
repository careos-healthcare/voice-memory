import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/early_archive/private_archive_report_copy.dart';
import 'package:archiveme_mobile/features/early_archive/private_archive_report_gates.dart';
import 'package:archiveme_mobile/features/early_archive/private_archive_report_model.dart';
import 'package:archiveme_mobile/features/private_report/private_report_analytics.dart';
import 'package:archiveme_mobile/features/private_report/private_report_copy.dart';
import 'package:archiveme_mobile/features/share/archive_share_actions.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Full private archive report in a bottom sheet — text only, copy or share.
class PrivateReportSheet extends StatelessWidget {
  const PrivateReportSheet({
    required this.report, required this.entryCount, required this.source, required this.isPro, required this.hasChange, required this.hasHelped, super.key,
    this.onCopy,
    this.onShare,
  });

  final PrivateArchiveReport report;
  final int entryCount;
  final String source;
  final bool isPro;
  final bool hasChange;
  final bool hasHelped;
  final Future<bool> Function(String text)? onCopy;
  final Future<bool> Function(String text)? onShare;

  static Future<void> show(
    BuildContext context, {
    required PrivateArchiveReport report,
    required int entryCount,
    required String source,
    required bool isPro,
    required bool hasChange,
    required bool hasHelped,
    Future<bool> Function(String text)? onCopy,
    Future<bool> Function(String text)? onShare,
  }) {
    PrivateReportAnalytics.opened(
      source: source,
      entryCount: entryCount,
      hasChange: hasChange,
      hasHelped: hasHelped,
    );
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
          source: source,
          isPro: isPro,
          hasChange: hasChange,
          hasHelped: hasHelped,
          onCopy: onCopy,
          onShare: onShare,
        ),
      ),
    );
  }

  bool get _isFullExport =>
      PrivateArchiveReportGates.showFullExport(isPro: isPro);

  String get _exportText => report.visiblePlainText(
    isPro: _isFullExport,
    previewSectionCount: report.previewSectionCount,
  );

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
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
                  style: ArchiveMobileTypography.listTitle(
                    context,
                  ).copyWith(fontSize: 16),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  PrivateArchiveReportCopy.previewBody,
                  key: const Key('private_report_sheet_preview_body'),
                  style: secondaryStyle,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                PrivateReportCopy.footer,
                key: const Key('private_report_sheet_footer'),
                style: secondaryStyle,
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
                  key: const Key('private_report_sheet_share_cta'),
                  onPressed: () => _share(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentPrimary,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(PrivateReportCopy.shareReportCta),
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
    PrivateReportAnalytics.copied(
      source: source,
      entryCount: entryCount,
      hasChange: hasChange,
      hasHelped: hasHelped,
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
      ArchiveShareActions.showFeedback(context, PrivateReportCopy.copySuccess);
    }
  }

  Future<void> _share(BuildContext context) async {
    PrivateReportAnalytics.shared(
      source: source,
      entryCount: entryCount,
      hasChange: hasChange,
      hasHelped: hasHelped,
    );
    if (onShare != null) {
      await onShare!(_exportText);
      return;
    }
    await ArchiveShareActions.shareShareText(
      context,
      text: _exportText,
      subject: report.title,
    );
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
      (line) => line.trim() == PrivateReportCopy.sectionFallback,
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